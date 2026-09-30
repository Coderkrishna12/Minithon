from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.account import Account, DarkWebAlert, Notification
from app.models.user import User
from app.services.breach_checker import email_breaches, email_pastes, http_client

router = APIRouter(prefix="/darkweb", tags=["darkweb"])

CREDENTIAL_CLASSES = {"passwords", "password hints", "password", "hashed passwords", "auth tokens"}


async def _add_alert(db: AsyncSession, user_id: int, alert_type: str, source: str, data_found: str, severity: str) -> bool:
    existing = await db.execute(
        select(DarkWebAlert).where(
            DarkWebAlert.user_id == user_id,
            DarkWebAlert.source == source,
            DarkWebAlert.data_found == data_found,
        )
    )
    if existing.scalar_one_or_none():
        return False
    db.add(DarkWebAlert(user_id=user_id, alert_type=alert_type, source=source, data_found=data_found, severity=severity))
    db.add(Notification(user_id=user_id, title=f"Exposure found: {source}", message=data_found, severity=severity))
    return True


@router.post("/scan")
async def scan_dark_web(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Paste dumps and credential leaks that contain the user's emails, from HIBP or XposedOrNot."""
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    emails = sorted({a.email_used.strip().lower() for a in accounts_result.scalars().all() if a.email_used})
    if user.email:
        emails = sorted(set(emails) | {user.email.strip().lower()})

    alerts_found = []
    errors = []
    async with http_client() as client:
        for email in emails:
            try:
                pastes = await email_pastes(client, email)
                breaches, _ = await email_breaches(client, email)
            except httpx.HTTPError as e:
                errors.append(f"Lookup failed for {email} ({e.__class__.__name__})")
                continue

            for p in pastes:
                source = f"{p['source']}{' #' + p['id'] if p.get('id') else ''}"
                detail = f"{email} appears in {p.get('title') or 'an untitled paste'}" + (f" ({p['date'][:10]})" if p.get("date") else "")
                if await _add_alert(db, user.id, "data_paste", source, detail, "warning"):
                    alerts_found.append({"email": email, "source": source, "source_type": "data_paste", "detail": detail, "severity": "warning"})

            for b in breaches:
                classes = {c.lower() for c in b.get("data", [])}
                if not classes & CREDENTIAL_CLASSES:
                    continue
                detail = f"{email} with {', '.join(b['data'])} from the {b['name']} breach is circulating in credential dumps"
                if await _add_alert(db, user.id, "credential_dump", b["name"], detail, "critical"):
                    alerts_found.append({"email": email, "source": b["name"], "source_type": "credential_dump", "detail": detail, "severity": "critical"})

    await db.commit()

    return {
        "scan_time": datetime.now(timezone.utc).isoformat(),
        "emails_checked": len(emails),
        "total_alerts": len(alerts_found),
        "alerts": alerts_found,
        "errors": errors,
    }


@router.get("/alerts")
async def list_alerts(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DarkWebAlert)
        .where(DarkWebAlert.user_id == user.id)
        .order_by(DarkWebAlert.created_at.desc())
    )
    alerts = result.scalars().all()
    return [
        {
            "id": a.id,
            "alert_type": a.alert_type,
            "source": a.source,
            "data_found": a.data_found,
            "severity": a.severity,
            "is_resolved": a.is_resolved,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        }
        for a in alerts
    ]


@router.patch("/alerts/{alert_id}/resolve")
async def resolve_alert(
    alert_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DarkWebAlert).where(DarkWebAlert.id == alert_id, DarkWebAlert.user_id == user.id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    alert.is_resolved = True
    await db.commit()
    return {"status": "resolved"}
