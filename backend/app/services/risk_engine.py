from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.account import Account, AccountConnection, BreachRecord, FixAction
from app.models.user import User


async def calculate_account_risk(account: Account, db: AsyncSession) -> float:
    breach_score = min(account.breach_count * 15, 30)
    permission_score = min(len(account.permissions or []) * 4, 20)
    password_reuse_score = 0
    if account.password_group:
        result = await db.execute(
            select(func.count(Account.id)).where(
                Account.user_id == account.user_id,
                Account.password_group == account.password_group,
                Account.id != account.id,
            )
        )
        reuse_count = result.scalar() or 0
        password_reuse_score = min(reuse_count * 5, 20)
    twofa_score = 0 if account.has_2fa else 15
    cascade_score = 0
    result = await db.execute(
        select(func.count(AccountConnection.id)).where(
            (AccountConnection.from_account_id == account.id)
            | (AccountConnection.to_account_id == account.id)
        )
    )
    connection_count = result.scalar() or 0
    cascade_score = min(connection_count * 5, 15)

    total = breach_score + permission_score + password_reuse_score + twofa_score + cascade_score
    return min(total, 100.0)


async def calculate_privacy_score(user_id: int, db: AsyncSession) -> int:
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()
    if not accounts:
        return 100

    total_risk = 0.0
    for account in accounts:
        risk = await calculate_account_risk(account, db)
        account.risk_score = risk
        total_risk += risk

    avg_risk = total_risk / len(accounts)
    privacy_score = max(0, int(100 - avg_risk))
    await db.commit()
    return privacy_score


async def find_single_points_of_failure(user_id: int, db: AsyncSession) -> list[Account]:
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()

    spof_list = []
    for account in accounts:
        conn_result = await db.execute(
            select(func.count(AccountConnection.id)).where(
                (AccountConnection.from_account_id == account.id)
                | (AccountConnection.to_account_id == account.id)
            )
        )
        conn_count = conn_result.scalar() or 0
        if conn_count >= 3:
            spof_list.append(account)

    spof_list.sort(key=lambda a: a.risk_score, reverse=True)
    return spof_list[:5]


async def generate_fix_actions(user_id: int, db: AsyncSession) -> list[FixAction]:
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()
    actions = []

    for account in accounts:
        if not account.has_2fa:
            actions.append(FixAction(
                user_id=user_id,
                account_id=account.id,
                action_type="enable_2fa",
                description=f"Enable two-factor authentication on {account.service_name}",
                priority=90 if account.category in ("finance", "email") else 60,
                risk_reduction=15.0,
                status="pending",
            ))

        if account.password_group:
            reuse_result = await db.execute(
                select(func.count(Account.id)).where(
                    Account.user_id == user_id,
                    Account.password_group == account.password_group,
                    Account.id != account.id,
                )
            )
            if (reuse_result.scalar() or 0) > 0:
                actions.append(FixAction(
                    user_id=user_id,
                    account_id=account.id,
                    action_type="change_password",
                    description=f"Change password on {account.service_name} (reused in group '{account.password_group}')",
                    priority=80,
                    risk_reduction=20.0,
                    status="pending",
                ))

        risky_perms = [p for p in (account.permissions or []) if p in ("contacts", "location", "camera", "microphone", "storage")]
        if len(risky_perms) >= 3:
            actions.append(FixAction(
                user_id=user_id,
                account_id=account.id,
                action_type="revoke_permission",
                description=f"Review excessive permissions on {account.service_name}: {', '.join(risky_perms)}",
                priority=50,
                risk_reduction=10.0,
                status="pending",
            ))

    actions.sort(key=lambda a: a.priority, reverse=True)
    return actions
