from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, AccountConnection
from app.core.security import get_current_user
from app.services.connections import refresh_user_graph
from app.services.risk_engine import find_single_points_of_failure

router = APIRouter(prefix="/graph", tags=["graph"])


@router.get("/")
async def get_graph_data(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await refresh_user_graph(user.id, db)
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()
    account_ids = [a.id for a in accounts]

    connections_result = await db.execute(
        select(AccountConnection).where(AccountConnection.from_account_id.in_(account_ids))
    )
    connections = connections_result.scalars().all()

    nodes = []
    for a in accounts:
        risk_level = "low"
        if a.risk_score >= 75:
            risk_level = "critical"
        elif a.risk_score >= 50:
            risk_level = "high"
        elif a.risk_score >= 25:
            risk_level = "medium"

        components = a.risk_components or {}
        nodes.append({
            "id": str(a.id),
            "label": a.service_name,
            "category": a.category or "other",
            "riskScore": a.risk_score,
            "riskLevel": risk_level,
            "has2fa": a.has_2fa,
            "twofaMethod": a.twofa_method,
            "loginMethod": a.login_method,
            "breachCount": a.breach_count,
            "blastRadius": components.get("cascading_impact", 0.0),
            "isKeystone": components.get("keystone", False),
            "reachableAccounts": components.get("reachable_accounts", 0),
            "riskComponents": components,
            "topPaths": components.get("top_paths", []),
            "permissions": a.permissions or [],
        })

    edges = []
    for c in connections:
        edges.append({
            "id": str(c.id),
            "source": str(c.from_account_id),
            "target": str(c.to_account_id),
            "type": c.connection_type,
        })

    spofs_accounts = await find_single_points_of_failure(user.id, db)
    spofs = [
        {
            "id": str(s.id),
            "service_name": s.service_name,
            "reachable_accounts": (s.risk_components or {}).get("reachable_accounts", 0),
            "risk_score": s.risk_score,
            "blast_radius": (s.risk_components or {}).get("cascading_impact", 0.0),
        }
        for s in spofs_accounts
    ]

    return {
        "nodes": nodes,
        "edges": edges,
        "spofs": spofs,
        "privacyScore": user.privacy_score,
    }


@router.post("/simulate-attack")
async def simulate_attack(
    entry_account_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await refresh_user_graph(user.id, db)
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = {a.id: a for a in accounts_result.scalars().all()}

    if entry_account_id not in accounts:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Account not found")

    account_ids = list(accounts.keys())
    connections_result = await db.execute(
        select(AccountConnection).where(AccountConnection.from_account_id.in_(account_ids))
    )
    connections = connections_result.scalars().all()

    adjacency: dict[int, list[int]] = {aid: [] for aid in account_ids}
    for c in connections:
        adjacency[c.from_account_id].append(c.to_account_id)
        adjacency[c.to_account_id].append(c.from_account_id)

    compromised = set()
    attack_path = []
    queue = [entry_account_id]
    compromised.add(entry_account_id)
    step = 0

    while queue:
        current = queue.pop(0)
        account = accounts[current]
        attack_path.append({
            "step": step,
            "accountId": current,
            "serviceName": account.service_name,
            "category": account.category,
            "riskScore": account.risk_score,
        })
        step += 1
        for neighbor in adjacency.get(current, []):
            if neighbor not in compromised:
                compromised.add(neighbor)
                queue.append(neighbor)

    finance_at_risk = sum(1 for aid in compromised if accounts[aid].category == "finance")

    return {
        "entryPoint": accounts[entry_account_id].service_name,
        "totalCompromised": len(compromised),
        "totalAccounts": len(accounts),
        "attackPath": attack_path,
        "financialAccountsAtRisk": finance_at_risk,
        "compromisedIds": [str(aid) for aid in compromised],
    }
