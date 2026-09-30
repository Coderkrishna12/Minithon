from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
import hashlib

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, DarkWebAlert, Notification
from app.core.security import get_current_user

router = APIRouter(prefix="/darkweb", tags=["darkweb"])

SIMULATED_DARK_WEB_SOURCES = [
    {"name": "Dark Forum Alpha", "type": "credential_dump"},
    {"name": "Paste Site Bravo", "type": "data_paste"},
    {"name": "Marketplace Charlie", "type": "data_sale"},
    {"name": "Hidden Wiki Delta", "type": "mention"},
]


@router.post("/scan")
async def scan_dark_web(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    alerts_found = []
    for account in accounts:
        email_hash = hashlib.md5((account.email_used or account.service_name).encode()).hexdigest()
        risk_value = int(email_hash[:2], 16)

        if risk_value < 40 or account.breach_count > 0:
            source = SIMULATED_DARK_WEB_SOURCES[risk_value % len(SIMULATED_DARK_WEB_SOURCES)]
            severity = "critical" if account.breach_count > 0 else "warning"

            existing = await db.execute(
                select(DarkWebAlert).where(
                    DarkWebAlert.user_id == user.id,
                    DarkWebAlert.source == source["name"],
                    DarkWebAlert.data_found.contains(account.service_name),
                )
            )
            if not existing.scalar_one_or_none():
                data_types = ["email"]
                if account.breach_count > 0:
                    data_types.extend(["password_hash", "username"])
                if account.category == "finance":
                    data_types.append("partial_card_number")

                alert = DarkWebAlert(
                    user_id=user.id,
                    alert_type=source["type"],
                    source=source["name"],
                    data_found=f"{account.service_name}: {', '.join(data_types)} found on {source['name']}",
                    severity=severity,
                )
                db.add(alert)

                notif = Notification(
                    user_id=user.id,
                    title=f"Dark Web Alert: {account.service_name}",
                    message=f"Your data from {account.service_name} was found on {source['name']}. Data types: {', '.join(data_types)}",
                    severity=severity,
                )
                db.add(notif)

                alerts_found.append({
                    "service": account.service_name,
                    "source": source["name"],
                    "source_type": source["type"],
                    "data_types": data_types,
                    "severity": severity,
                })

    await db.commit()

    return {
        "scan_time": datetime.now(timezone.utc).isoformat(),
        "total_alerts": len(alerts_found),
        "alerts": alerts_found,
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
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Alert not found")

    alert.is_resolved = True
    await db.commit()
    return {"status": "resolved"}
