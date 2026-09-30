from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, AccountConnection
from app.schemas.account import (
    AccountCreate, AccountUpdate, AccountResponse,
    ConnectionCreate, ConnectionResponse,
)
from app.core.security import get_current_user
from app.services.risk_engine import calculate_account_risk

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("/", response_model=list[AccountResponse])
async def list_accounts(
    category: str | None = None,
    risk_level: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Account).where(Account.user_id == user.id)
    if category:
        query = query.where(Account.category == category)
    result = await db.execute(query.order_by(Account.risk_score.desc()))
    accounts = result.scalars().all()

    if risk_level:
        thresholds = {"critical": 75, "high": 50, "medium": 25, "low": 0}
        min_risk = thresholds.get(risk_level, 0)
        max_risk = {"critical": 100, "high": 75, "medium": 50, "low": 25}.get(risk_level, 100)
        accounts = [a for a in accounts if min_risk <= a.risk_score < max_risk]

    return [AccountResponse.model_validate(a) for a in accounts]


@router.post("/", response_model=AccountResponse, status_code=201)
async def create_account(
    data: AccountCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    account = Account(user_id=user.id, **data.model_dump())
    db.add(account)
    await db.commit()
    await db.refresh(account)

    account.risk_score = await calculate_account_risk(account, db)
    await db.commit()
    await db.refresh(account)
    return AccountResponse.model_validate(account)


@router.get("/{account_id}", response_model=AccountResponse)
async def get_account(
    account_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Account).where(Account.id == account_id, Account.user_id == user.id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return AccountResponse.model_validate(account)


@router.put("/{account_id}", response_model=AccountResponse)
async def update_account(
    account_id: int,
    data: AccountUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Account).where(Account.id == account_id, Account.user_id == user.id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(account, field, value)

    account.risk_score = await calculate_account_risk(account, db)
    await db.commit()
    await db.refresh(account)
    return AccountResponse.model_validate(account)


@router.delete("/{account_id}", status_code=204)
async def delete_account(
    account_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Account).where(Account.id == account_id, Account.user_id == user.id))
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    await db.delete(account)
    await db.commit()


@router.post("/connections", response_model=ConnectionResponse, status_code=201)
async def create_connection(
    data: ConnectionCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for aid in [data.from_account_id, data.to_account_id]:
        r = await db.execute(select(Account).where(Account.id == aid, Account.user_id == user.id))
        if not r.scalar_one_or_none():
            raise HTTPException(status_code=404, detail=f"Account {aid} not found")

    conn = AccountConnection(**data.model_dump())
    db.add(conn)
    await db.commit()
    await db.refresh(conn)
    return ConnectionResponse.model_validate(conn)


@router.get("/connections/all", response_model=list[ConnectionResponse])
async def list_connections(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    account_ids_result = await db.execute(select(Account.id).where(Account.user_id == user.id))
    account_ids = [r[0] for r in account_ids_result.fetchall()]
    if not account_ids:
        return []

    result = await db.execute(
        select(AccountConnection).where(
            AccountConnection.from_account_id.in_(account_ids)
        )
    )
    return [ConnectionResponse.model_validate(c) for c in result.scalars().all()]
