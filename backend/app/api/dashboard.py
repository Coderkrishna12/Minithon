from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, FixAction, ScoreHistory
from app.schemas.account import DashboardResponse, AccountResponse, FixActionResponse
from app.core.security import get_current_user
from app.services.risk_engine import (
    calculate_privacy_score,
    find_single_points_of_failure,
    generate_fix_actions,
    _load_network,
    score_network,
)
from app.services.blockchain import record_audit

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/", response_model=DashboardResponse)
async def get_dashboard(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    privacy_score = await calculate_privacy_score(user.id, db)
    user.privacy_score = privacy_score
    await db.commit()

    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()
    total_accounts = len(accounts)
    accounts_at_risk = sum(1 for a in accounts if a.risk_score >= 50)
    breaches_found = sum(a.breach_count for a in accounts)

    # Keep the timeline current: record the score whenever it has moved since the last entry.
    last = (await db.execute(
        select(ScoreHistory).where(ScoreHistory.user_id == user.id)
        .order_by(ScoreHistory.created_at.desc(), ScoreHistory.id.desc()).limit(1)
    )).scalar_one_or_none()
    if accounts and (last is None or last.privacy_score != privacy_score):
        db.add(ScoreHistory(
            user_id=user.id, privacy_score=privacy_score, total_accounts=total_accounts,
            accounts_at_risk=accounts_at_risk, breaches_total=breaches_found,
            event_type="score_change" if last else "baseline",
            event_description="Score changed" if last else "First score on record",
        ))
        await db.commit()

    fixes_result = await db.execute(select(FixAction).where(FixAction.user_id == user.id))
    fixes = fixes_result.scalars().all()
    fixes_completed = sum(1 for f in fixes if f.status == "completed")
    fixes_pending = sum(1 for f in fixes if f.status == "pending")

    spof = await find_single_points_of_failure(user.id, db)

    risk_distribution = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    category_breakdown: dict[str, int] = {}
    for a in accounts:
        if a.risk_score >= 75:
            risk_distribution["critical"] += 1
        elif a.risk_score >= 50:
            risk_distribution["high"] += 1
        elif a.risk_score >= 25:
            risk_distribution["medium"] += 1
        else:
            risk_distribution["low"] += 1
        cat = a.category or "uncategorized"
        category_breakdown[cat] = category_breakdown.get(cat, 0) + 1

    return DashboardResponse(
        privacy_score=privacy_score,
        total_accounts=total_accounts,
        accounts_at_risk=accounts_at_risk,
        breaches_found=breaches_found,
        fixes_completed=fixes_completed,
        fixes_pending=fixes_pending,
        single_points_of_failure=[AccountResponse.model_validate(a) for a in spof],
        risk_distribution=risk_distribution,
        category_breakdown=category_breakdown,
    )


@router.get("/fixes", response_model=list[FixActionResponse])
async def get_fix_actions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(FixAction).where(FixAction.user_id == user.id, FixAction.status == "pending"))
    if not existing.scalars().all():
        actions = await generate_fix_actions(user.id, db)
        for action in actions:
            db.add(action)
        await db.commit()

    result = await db.execute(
        select(FixAction).where(FixAction.user_id == user.id).order_by(FixAction.priority.desc())
    )
    return [FixActionResponse.model_validate(f) for f in result.scalars().all()]


@router.patch("/fixes/{fix_id}/complete", response_model=FixActionResponse)
async def complete_fix(
    fix_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    result = await db.execute(select(FixAction).where(FixAction.id == fix_id, FixAction.user_id == user.id))
    fix = result.scalar_one_or_none()
    if not fix:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Fix action not found")
    account_result = await db.execute(select(Account).where(Account.id == fix.account_id, Account.user_id == user.id))
    account = account_result.scalar_one_or_none()
    if not account:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Account for this fix was not found")

    # This records the user's confirmation; PrivacyShield does not change the external service.
    if fix.action_type == "enable_2fa":
        account.has_2fa, account.twofa_method = True, "totp"
    elif fix.action_type == "change_password":
        account.password_group = None
    elif fix.action_type == "revoke_permission":
        account.permissions = []

    fix.status = "completed"
    fix.completed_at = datetime.now(timezone.utc)
    await db.commit()
    new_score = await calculate_privacy_score(user.id, db)
    user.privacy_score = new_score
    db.add(ScoreHistory(
        user_id=user.id, privacy_score=new_score, event_type="fix_completed",
        event_description=f"User confirmed {fix.action_type} for {account.service_name}",
    ))
    receipt = await record_audit(
        user.id, "fix_completed", f"User confirmed {fix.action_type} for {account.service_name}",
        {"fix_id": fix.id, "account_id": account.id, "action_type": fix.action_type,
         "privacy_score": new_score}, db,
    )
    fix.blockchain_tx_hash = receipt.blockchain_tx_hash
    await db.commit()
    await db.refresh(fix)
    return FixActionResponse.model_validate(fix)


@router.get("/fixes/{fix_id}/preview")
async def preview_fix(
    fix_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from fastapi import HTTPException
    result = await db.execute(select(FixAction).where(FixAction.id == fix_id, FixAction.user_id == user.id))
    fix = result.scalar_one_or_none()
    if not fix or fix.status != "pending":
        raise HTTPException(status_code=404, detail="Pending fix action not found")
    accounts, connections, breaches = await _load_network(user.id, db)
    _, _, before = score_network(accounts, connections, breaches)
    target = next((a for a in accounts if a.id == fix.account_id), None)
    if not target:
        raise HTTPException(status_code=404, detail="Account for this fix was not found")
    simulated = []
    for account in accounts:
        item = {
            "id": account.id, "category": account.category, "has_2fa": account.has_2fa,
            "twofa_method": account.twofa_method, "permissions": list(account.permissions or []),
            "password_group": account.password_group, "breach_count": account.breach_count,
        }
        if account.id == target.id:
            if fix.action_type == "enable_2fa":
                item["has_2fa"], item["twofa_method"] = True, "totp"
            elif fix.action_type == "change_password":
                item["password_group"] = None
            elif fix.action_type == "revoke_permission":
                item["permissions"] = []
        simulated.append(item)
    simulated_edges = [
        {"from_account_id": edge.from_account_id, "to_account_id": edge.to_account_id,
         "connection_type": edge.connection_type}
        for edge in connections
        if not (fix.action_type == "change_password" and edge.connection_type == "password_reuse"
                and target.id in (edge.from_account_id, edge.to_account_id))
    ]
    _, _, after = score_network(simulated, simulated_edges, breaches)
    minutes = {"enable_2fa": 10, "change_password": 15, "revoke_permission": 8}.get(fix.action_type, 0)
    return {
        "fix_id": fix.id, "account": target.service_name, "action_type": fix.action_type,
        "before_score": before, "after_score": after,
        "score_improvement": max(0, after - before), "estimated_minutes": minutes,
        "changes_external_account": False,
        "message": "Preview is an estimate. You must make this change with the service and confirm it here.",
    }
