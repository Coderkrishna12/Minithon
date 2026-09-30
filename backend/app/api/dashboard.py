from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, FixAction
from app.schemas.account import DashboardResponse, AccountResponse, FixActionResponse
from app.core.security import get_current_user
from app.services.risk_engine import (
    calculate_privacy_score,
    find_single_points_of_failure,
    generate_fix_actions,
)

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
    fix.status = "completed"
    fix.completed_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(fix)
    return FixActionResponse.model_validate(fix)
