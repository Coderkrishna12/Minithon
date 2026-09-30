import asyncio
import logging

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.websocket import notify_breach
from app.core.config import get_settings
from app.db.session import async_session
from app.models.account import Account, BreachRecord
from app.services.breach_checker import scan_all_accounts

log = logging.getLogger(__name__)


async def _breach_ids(user_id: int, db: AsyncSession) -> set[int]:
    rows = await db.execute(
        select(BreachRecord.id).join(Account, Account.id == BreachRecord.account_id).where(Account.user_id == user_id)
    )
    return set(rows.scalars().all())


async def scan_and_notify(user_id: int, db: AsyncSession) -> dict:
    """Run a full scan and push any breach records that did not exist before to the user's live sockets."""
    before = await _breach_ids(user_id, db)
    result = await scan_all_accounts(user_id, db)
    new_ids = (await _breach_ids(user_id, db)) - before
    if new_ids:
        rows = await db.execute(
            select(BreachRecord, Account.service_name)
            .join(Account, Account.id == BreachRecord.account_id)
            .where(BreachRecord.id.in_(new_ids))
        )
        for record, service in rows.all():
            await notify_breach(user_id, {
                "service": service,
                "breach": record.breach_name,
                "date": record.breach_date.date().isoformat() if record.breach_date else None,
                "data_exposed": record.data_exposed,
                "confirmed": record.source in ("hibp_account", "xposedornot"),
            })
    for exposure in result.get("unlisted_exposures", []):
        await notify_breach(user_id, {"service": None, "breach": exposure["name"], "email": exposure["email"], "unlisted": True})
    return {**result, "new_breaches": len(new_ids)}


async def run_monitor() -> None:
    interval = get_settings().monitor_interval_minutes
    if interval <= 0:
        return
    while True:
        await asyncio.sleep(interval * 60)
        async with async_session() as db:
            user_ids = (await db.execute(select(Account.user_id).group_by(Account.user_id).having(func.count() > 0))).scalars().all()
        for user_id in user_ids:
            try:
                async with async_session() as db:
                    await scan_and_notify(user_id, db)
            except Exception:
                log.exception("Background scan failed for user %s", user_id)
