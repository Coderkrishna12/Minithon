from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timezone, timedelta

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
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    result = await db.execute(
        select(ScoreHistory)
        .where(ScoreHistory.user_id == user.id, ScoreHistory.created_at >= cutoff)
        .order_by(ScoreHistory.created_at.asc())
    )
    history = result.scalars().all()
    if not history:
        await record_score_snapshot("baseline", "First score on record", user, db)
        result = await db.execute(
            select(ScoreHistory).where(ScoreHistory.user_id == user.id).order_by(ScoreHistory.created_at.asc())
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
            "created_at": h.created_at.isoformat() if h.created_at else None,
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


def _aware(dt: datetime | None) -> datetime | None:
    """SQLite hands datetimes back without a timezone; treat them as UTC."""
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


@router.get("/events")
async def get_events_timeline(
    days: int = 90,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    events = []

    def add(kind: str, title: str, severity: str, when: datetime | None, description: str | None = None):
        when = _aware(when)
        if when and when >= cutoff:
            events.append({"type": kind, "title": title, "description": description,
                           "severity": severity, "date": when.isoformat()})

    accounts = (await db.execute(select(Account).where(Account.user_id == user.id))).scalars().all()
    names = {a.id: a.service_name for a in accounts}
    for a in accounts:
        add("account_added", f"Started tracking {a.service_name}", "info", a.created_at,
            f"Added via {a.added_via.replace('_', ' ')}" if a.added_via else None)

    if names:
        breaches = (await db.execute(select(BreachRecord).where(BreachRecord.account_id.in_(list(names))))).scalars().all()
        for b in breaches:
            exposed = ", ".join(b.data_exposed or []) or None
            add("breach", f"{names.get(b.account_id, 'Account')} found in the {b.breach_name} breach", "critical",
                b.created_at, f"Exposed: {exposed}" if exposed else None)

    fixes = (await db.execute(
        select(FixAction).where(FixAction.user_id == user.id, FixAction.status == "completed")
    )).scalars().all()
    for f in fixes:
        add("fix_completed", f"Fixed: {f.description}", "success", f.completed_at,
            f"Score +{f.risk_reduction:.0f}" if f.risk_reduction else None)

    history = (await db.execute(
        select(ScoreHistory).where(ScoreHistory.user_id == user.id).order_by(ScoreHistory.created_at.asc())
    )).scalars().all()
    previous = None
    for h in history:
        if previous is not None and h.privacy_score != previous:
            delta = h.privacy_score - previous
            add("score_change", f"Privacy score {'rose' if delta > 0 else 'fell'} to {h.privacy_score}",
                "success" if delta > 0 else "warning", h.created_at, f"{delta:+d} points")
        previous = h.privacy_score

    audits = (await db.execute(select(AuditLog).where(AuditLog.user_id == user.id))).scalars().all()
    for a in audits:
        if a.action == "fix_completed":
            continue  # already shown as a fix event
        add("audit", a.details or a.action.replace("_", " "), "info", a.created_at,
            f"Receipt {a.blockchain_tx_hash[:14]}…" if a.blockchain_tx_hash else None)

    events.sort(key=lambda e: e["date"], reverse=True)
    return events[:100]
