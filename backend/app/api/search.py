from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, BreachRecord, Notification, AuditLog
from app.core.security import get_current_user

router = APIRouter(prefix="/search", tags=["search"])


@router.get("/")
async def global_search(
    q: str = Query(..., min_length=1),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q_lower = f"%{q.lower()}%"

    accounts_result = await db.execute(
        select(Account).where(
            Account.user_id == user.id,
            or_(
                Account.service_name.ilike(q_lower),
                Account.email_used.ilike(q_lower),
                Account.category.ilike(q_lower),
                Account.notes.ilike(q_lower),
            ),
        )
    )
    accounts = accounts_result.scalars().all()

    account_ids_result = await db.execute(select(Account.id).where(Account.user_id == user.id))
    account_ids = [r[0] for r in account_ids_result.fetchall()]

    breaches = []
    if account_ids:
        breach_result = await db.execute(
            select(BreachRecord).where(
                BreachRecord.account_id.in_(account_ids),
                BreachRecord.breach_name.ilike(q_lower),
            )
        )
        breaches = breach_result.scalars().all()

    notif_result = await db.execute(
        select(Notification).where(
            Notification.user_id == user.id,
            or_(
                Notification.title.ilike(q_lower),
                Notification.message.ilike(q_lower),
            ),
        ).limit(20)
    )
    notifications = notif_result.scalars().all()

    audit_result = await db.execute(
        select(AuditLog).where(
            AuditLog.user_id == user.id,
            or_(
                AuditLog.action.ilike(q_lower),
                AuditLog.details.ilike(q_lower),
            ),
        ).limit(20)
    )
    audit_logs = audit_result.scalars().all()

    return {
        "query": q,
        "results": {
            "accounts": [
                {
                    "id": a.id,
                    "type": "account",
                    "title": a.service_name,
                    "subtitle": a.email_used or a.category,
                    "risk_score": a.risk_score,
                }
                for a in accounts
            ],
            "breaches": [
                {
                    "id": b.id,
                    "type": "breach",
                    "title": b.breach_name,
                    "subtitle": b.source,
                    "date": b.breach_date.isoformat() if b.breach_date else None,
                }
                for b in breaches
            ],
            "notifications": [
                {
                    "id": n.id,
                    "type": "notification",
                    "title": n.title,
                    "subtitle": n.message[:100],
                    "severity": n.severity,
                }
                for n in notifications
            ],
            "audit_logs": [
                {
                    "id": a.id,
                    "type": "audit",
                    "title": a.action,
                    "subtitle": a.details,
                }
                for a in audit_logs
            ],
        },
        "total": len(accounts) + len(breaches) + len(notifications) + len(audit_logs),
    }
