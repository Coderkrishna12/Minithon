from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import timedelta

from app.core.time import utcnow, ensure_aware
from app.db.session import get_db
from app.models.user import User
from app.models.account import (
    Account, BreachRecord, FixAction, AuditLog, Notification, ScoreHistory,
)
from app.core.security import get_current_user
from app.services.risk_engine import calculate_privacy_score

router = APIRouter(prefix="/timeline", tags=["timeline"])


@router.get("/score-history")
async def get_score_history(
    days: int = 90,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cutoff = utcnow() - timedelta(days=days)
    result = await db.execute(
        select(ScoreHistory)
        .where(ScoreHistory.user_id == user.id, ScoreHistory.created_at >= cutoff)
        .order_by(ScoreHistory.created_at.asc())
    )
    history = result.scalars().all()
    return [
        {
            "id": h.id,
            "privacy_score": h.privacy_score,
            "total_accounts": h.total_accounts,
            "accounts_at_risk": h.accounts_at_risk,
            "breaches_total": h.breaches_total,
            "event_type": h.event_type,
            "event_description": h.event_description,
            "created_at": ensure_aware(h.created_at).isoformat() if h.created_at else None,
        }
        for h in history
    ]


@router.post("/snapshot")
async def record_score_snapshot(
    event_type: str = "manual_check",
    event_description: str = "",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    score = await calculate_privacy_score(user.id, db)
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    snapshot = ScoreHistory(
        user_id=user.id,
        privacy_score=score,
        total_accounts=len(accounts),
        accounts_at_risk=sum(1 for a in accounts if a.risk_score >= 50),
        breaches_total=sum(a.breach_count for a in accounts),
        event_type=event_type,
        event_description=event_description,
    )
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)
    return {"id": snapshot.id, "privacy_score": score}


@router.get("/events")
async def get_events_timeline(
    days: int = 90,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cutoff = utcnow() - timedelta(days=days)
    events = []

    account_ids_result = await db.execute(select(Account.id).where(Account.user_id == user.id))
    account_ids = [r[0] for r in account_ids_result.fetchall()]

    if account_ids:
        breach_result = await db.execute(
            select(BreachRecord)
            .where(BreachRecord.account_id.in_(account_ids), BreachRecord.created_at >= cutoff)
            .order_by(BreachRecord.created_at.desc())
        )
        for b in breach_result.scalars().all():
            events.append({
                "type": "breach",
                "title": f"Breach detected: {b.breach_name}",
                "severity": "critical",
                "date": ensure_aware(b.created_at).isoformat() if b.created_at else None,
            })

    fix_result = await db.execute(
        select(FixAction)
        .where(FixAction.user_id == user.id, FixAction.status == "completed")
        .order_by(FixAction.completed_at.desc())
    )
    for f in fix_result.scalars().all():
        completed = ensure_aware(f.completed_at)
        if completed and completed >= cutoff:
            events.append({
                "type": "fix_completed",
                "title": f"Fix completed: {f.description}",
                "severity": "info",
                "date": completed.isoformat(),
            })

    audit_result = await db.execute(
        select(AuditLog)
        .where(AuditLog.user_id == user.id, AuditLog.created_at >= cutoff)
        .order_by(AuditLog.created_at.desc())
    )
    for a in audit_result.scalars().all():
        events.append({
            "type": "audit",
            "title": a.details or a.action,
            "severity": "info",
            "date": ensure_aware(a.created_at).isoformat() if a.created_at else None,
        })

    events.sort(key=lambda e: e["date"] or "", reverse=True)
    return events[:100]
