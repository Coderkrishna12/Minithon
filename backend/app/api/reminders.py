from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone, timedelta

from app.db.session import get_db
from app.models.user import User
from app.models.account import ReviewReminder, Notification
from app.core.security import get_current_user

router = APIRouter(prefix="/reminders", tags=["reminders"])

DEFAULT_REMINDERS = [
    {"type": "password_review", "title": "Review Passwords", "desc": "Check for weak or reused passwords across your accounts", "days": 30},
    {"type": "permission_audit", "title": "Permission Audit", "desc": "Review app permissions and revoke unnecessary access", "days": 60},
    {"type": "2fa_check", "title": "2FA Verification", "desc": "Ensure 2FA is enabled on all critical accounts", "days": 14},
    {"type": "breach_scan", "title": "Breach Scan", "desc": "Scan accounts for new data breaches", "days": 7},
    {"type": "privacy_policy", "title": "Privacy Policy Review", "desc": "Check for changes in service privacy policies", "days": 90},
    {"type": "account_cleanup", "title": "Account Cleanup", "desc": "Review and remove unused accounts", "days": 90},
]


class ReminderCreate(BaseModel):
    reminder_type: str
    title: str
    description: str = ""
    frequency_days: int = 30


@router.get("/")
async def list_reminders(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReviewReminder).where(ReviewReminder.user_id == user.id)
        .order_by(ReviewReminder.next_trigger.asc())
    )
    reminders = result.scalars().all()

    if not reminders:
        now = datetime.now(timezone.utc)
        for r in DEFAULT_REMINDERS:
            reminder = ReviewReminder(
                user_id=user.id,
                reminder_type=r["type"],
                title=r["title"],
                description=r["desc"],
                frequency_days=r["days"],
                next_trigger=now + timedelta(days=r["days"]),
            )
            db.add(reminder)
        await db.commit()

        result = await db.execute(
            select(ReviewReminder).where(ReviewReminder.user_id == user.id)
            .order_by(ReviewReminder.next_trigger.asc())
        )
        reminders = result.scalars().all()

    now = datetime.now(timezone.utc)
    return [
        {
            "id": r.id,
            "reminder_type": r.reminder_type,
            "title": r.title,
            "description": r.description,
            "frequency_days": r.frequency_days,
            "is_active": r.is_active,
            "is_due": r.next_trigger <= now if r.next_trigger else False,
            "last_triggered": r.last_triggered.isoformat() if r.last_triggered else None,
            "next_trigger": r.next_trigger.isoformat() if r.next_trigger else None,
        }
        for r in reminders
    ]


@router.post("/")
async def create_reminder(
    data: ReminderCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    reminder = ReviewReminder(
        user_id=user.id,
        reminder_type=data.reminder_type,
        title=data.title,
        description=data.description,
        frequency_days=data.frequency_days,
        next_trigger=datetime.now(timezone.utc) + timedelta(days=data.frequency_days),
    )
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    return {"id": reminder.id, "title": reminder.title}


@router.post("/{reminder_id}/complete")
async def complete_reminder(
    reminder_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReviewReminder).where(ReviewReminder.id == reminder_id, ReviewReminder.user_id == user.id)
    )
    reminder = result.scalar_one_or_none()
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")

    now = datetime.now(timezone.utc)
    reminder.last_triggered = now
    reminder.next_trigger = now + timedelta(days=reminder.frequency_days)
    await db.commit()

    return {"status": "completed", "next_trigger": reminder.next_trigger.isoformat()}


@router.patch("/{reminder_id}/toggle")
async def toggle_reminder(
    reminder_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ReviewReminder).where(ReviewReminder.id == reminder_id, ReviewReminder.user_id == user.id)
    )
    reminder = result.scalar_one_or_none()
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")

    reminder.is_active = not reminder.is_active
    await db.commit()
    return {"is_active": reminder.is_active}
