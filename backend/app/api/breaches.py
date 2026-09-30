from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, BreachRecord
from app.core.security import get_current_user
from app.services.breach_checker import check_account_breaches
from app.services.monitor import scan_and_notify

router = APIRouter(prefix="/breaches", tags=["breaches"])


@router.post("/scan-all")
async def scan_all(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await scan_and_notify(user.id, db)


@router.post("/scan/{account_id}")
async def scan_account(
    account_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from fastapi import HTTPException
    result = await db.execute(select(Account).where(Account.id == account_id, Account.user_id == user.id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    breaches = await check_account_breaches(account, db)
    return {
        "account": account.service_name,
        "breaches_found": len(breaches),
        "breaches": breaches,
    }


@router.get("/history")
async def breach_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    account_ids_result = await db.execute(select(Account.id).where(Account.user_id == user.id))
    account_ids = [r[0] for r in account_ids_result.fetchall()]
    if not account_ids:
        return []

    result = await db.execute(
        select(BreachRecord).where(BreachRecord.account_id.in_(account_ids)).order_by(BreachRecord.created_at.desc())
    )
    records = result.scalars().all()

    accounts_result = await db.execute(select(Account).where(Account.id.in_(account_ids)))
    accounts_map = {a.id: a.service_name for a in accounts_result.scalars().all()}

    return [
        {
            "id": r.id,
            "account_name": accounts_map.get(r.account_id, "Unknown"),
            "breach_name": r.breach_name,
            "breach_date": r.breach_date.isoformat() if r.breach_date else None,
            "data_exposed": r.data_exposed,
            "source": r.source,
        }
        for r in records
    ]
