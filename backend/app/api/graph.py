from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, AccountConnection
from app.core.security import get_current_user
from app.services.attack_simulator import report, simulate
from app.services.connections import refresh_user_graph
from app.services.risk_engine import _load_network

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

        nodes.append({
            "id": str(a.id),
            "label": a.service_name,
            "category": a.category or "other",
            "riskScore": a.risk_score,
            "riskLevel": risk_level,
            "has2fa": a.has_2fa,
            "loginMethod": a.login_method,
            "breachCount": a.breach_count,
        })

    edges = []
    for c in connections:
        edges.append({
            "id": str(c.id),
            "source": str(c.from_account_id),
            "target": str(c.to_account_id),
            "type": c.connection_type,
        })

    return {"nodes": nodes, "edges": edges}


@router.post("/simulate-attack")
async def simulate_attack(
    entry_account_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Older response shape for the web graph; the full simulator lives at /attack-sim/run."""
    await refresh_user_graph(user.id, db)
    accounts, connections, breaches = await _load_network(user.id, db)
    if entry_account_id not in {a.id for a in accounts}:
        raise HTTPException(status_code=404, detail="Account not found")
    result = report(accounts, simulate(accounts, connections, entry_account_id), breaches)
    entry = result["entry"]
    path = [{"step": 0, "accountId": entry["id"], "serviceName": entry["service"], "category": entry["category"]}]
    path += [
        {"step": s["order"], "accountId": s["to_id"], "serviceName": s["to"], "via": s["via"],
         "probability": s["probability"]}
        for s in result["steps"]
    ]
    reached = [n["id"] for n in result["nodes"] if n["status"] in ("entry", "compromised", "data_exposed")]
    return {
        "entryPoint": entry["service"],
        "totalCompromised": len(reached),
        "totalAccounts": len(accounts),
        "attackPath": path,
        "financialAccountsAtRisk": len(result["damage"]["financial_accounts_at_risk"]),
        "compromisedIds": [str(i) for i in reached],
    }
