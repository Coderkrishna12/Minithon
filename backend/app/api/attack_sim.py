from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.account import AttackSimulation, FixAction
from app.models.user import User
from app.services.attack_simulator import (
    DEMO_ACCOUNTS, DEMO_BREACHES, DEMO_EDGES,
    _twofa, apply_fixes, blast_counts, default_fixes, report, simulate,
)
from app.services.connections import refresh_user_graph
from app.services.risk_engine import _load_network, generate_fix_actions

router = APIRouter(prefix="/attack-sim", tags=["attack simulator"])

FIX_LABELS = {
    "enable_2fa": "Turn on 2FA",
    "change_password": "Use a unique password",
    "revoke_permission": "Revoke extra permissions",
}


class RunRequest(BaseModel):
    entry_account_id: int
    # Also simulate the same attack as if every recommended fix were done.
    compare_fixes: bool = True
    save: bool = True


async def _network(user_id: int, db: AsyncSession):
    await refresh_user_graph(user_id, db)
    return await _load_network(user_id, db)


async def _recommended_fixes(user_id: int, db: AsyncSession) -> list:
    pending = (await db.execute(
        select(FixAction).where(FixAction.user_id == user_id, FixAction.status == "pending")
    )).scalars().all()
    return list(pending) or await generate_fix_actions(user_id, db)


@router.get("/entry-points")
async def entry_points(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Every account as a possible entry point, most dangerous first."""
    accounts, connections, breaches = await _network(user.id, db)
    return _entry_points(accounts, connections, {b.account_id for b in breaches})


@router.post("/run")
async def run_simulation(data: RunRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    accounts, connections, breaches = await _network(user.id, db)
    if data.entry_account_id not in {a.id for a in accounts}:
        raise HTTPException(status_code=404, detail="Account not found")

    before = report(accounts, simulate(accounts, connections, data.entry_account_id), breaches)

    after, fixes_applied = None, []
    if data.compare_fixes:
        fixes = await _recommended_fixes(user.id, db)
        names = {a.id: a.service_name for a in accounts}
        fixes_applied = [
            {"id": f.id, "account_id": f.account_id, "service": names.get(f.account_id), "action_type": f.action_type,
             "label": f"{FIX_LABELS.get(f.action_type, f.action_type)} on {names.get(f.account_id)}"}
            for f in fixes
        ]
        fixed_accounts, fixed_edges = apply_fixes(accounts, connections, fixes)
        after = report(fixed_accounts, simulate(fixed_accounts, fixed_edges, data.entry_account_id), breaches)

    previous = (await db.execute(
        select(AttackSimulation)
        .where(AttackSimulation.user_id == user.id, AttackSimulation.entry_account_id == data.entry_account_id)
        .order_by(AttackSimulation.created_at.desc(), AttackSimulation.id.desc())
        .limit(1)
    )).scalar_one_or_none()
    previous_out = previous and {
        "at": previous.created_at.isoformat() if previous.created_at else None,
        "accounts_reachable": previous.accounts_reachable,
        "financial_at_risk": previous.financial_at_risk,
        "damage_score": previous.damage_score,
    }

    run_id = None
    if data.save:
        d = before["damage"]
        record = AttackSimulation(
            user_id=user.id, entry_account_id=data.entry_account_id, entry_service=before["entry"]["service"],
            accounts_reachable=d["accounts_reachable"], financial_at_risk=len(d["financial_accounts_at_risk"]),
            damage_score=d["damage_score"],
        )
        db.add(record)
        await db.commit()
        run_id = record.id

    return {
        "run_id": run_id,
        "before": before,
        "after": after,
        "fixes_applied": fixes_applied,
        "improvement": after and {
            "accounts_reachable": before["damage"]["accounts_reachable"] - after["damage"]["accounts_reachable"],
            "damage_score": before["damage"]["damage_score"] - after["damage"]["damage_score"],
            "financial_accounts": len(before["damage"]["financial_accounts_at_risk"])
            - len(after["damage"]["financial_accounts_at_risk"]),
        },
        "previous_run": previous_out,
    }


@router.get("/history")
async def history(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    runs = (await db.execute(
        select(AttackSimulation).where(AttackSimulation.user_id == user.id)
        .order_by(AttackSimulation.created_at.desc(), AttackSimulation.id.desc()).limit(50)
    )).scalars().all()
    return [
        {"id": r.id, "entry_account_id": r.entry_account_id, "entry_service": r.entry_service,
         "accounts_reachable": r.accounts_reachable, "financial_at_risk": r.financial_at_risk,
         "damage_score": r.damage_score, "at": r.created_at.isoformat() if r.created_at else None}
        for r in runs
    ]


def _entry_points(accounts, connections, breached: set[int]) -> dict:
    reach = blast_counts(accounts, connections)
    get = lambda a, k: a[k] if isinstance(a, dict) else getattr(a, k)  # noqa: E731
    points = sorted(
        (
            {
                "id": get(a, "id"),
                "service": get(a, "service_name"),
                "category": get(a, "category") or "other",
                "twofa": _twofa(a),
                "breached": get(a, "id") in breached,
                "reaches": reach[get(a, "id")][0],
                "expected_damage": round(reach[get(a, "id")][1], 2),
            }
            for a in accounts
        ),
        key=lambda p: (-p["reaches"], -p["expected_damage"], not p["breached"], p["service"].lower()),
    )
    return {
        "entry_points": points,
        "suggested_id": points[0]["id"] if points and points[0]["reaches"] else None,
        "total_accounts": len(accounts),
    }


@router.get("/demo/entry-points")
async def demo_entry_points(user: User = Depends(get_current_user)):
    """Entry points on the built-in sample network (nothing is read from or written to your data)."""
    return {**_entry_points(DEMO_ACCOUNTS, DEMO_EDGES, {b["account_id"] for b in DEMO_BREACHES}), "demo": True}


@router.post("/demo/run")
async def demo_run(data: RunRequest, user: User = Depends(get_current_user)):
    if data.entry_account_id not in {a["id"] for a in DEMO_ACCOUNTS}:
        raise HTTPException(status_code=404, detail="Account not found in the sample network")
    before = report(DEMO_ACCOUNTS, simulate(DEMO_ACCOUNTS, DEMO_EDGES, data.entry_account_id), DEMO_BREACHES)
    fixes = default_fixes(DEMO_ACCOUNTS)
    fixed_accounts, fixed_edges = apply_fixes(DEMO_ACCOUNTS, DEMO_EDGES, fixes)
    after = report(fixed_accounts, simulate(fixed_accounts, fixed_edges, data.entry_account_id), DEMO_BREACHES)
    names = {a["id"]: a["service_name"] for a in DEMO_ACCOUNTS}
    return {
        "demo": True,
        "run_id": None,
        "before": before,
        "after": after,
        "fixes_applied": [
            {"id": None, "account_id": f["account_id"], "service": names[f["account_id"]], "action_type": f["action_type"],
             "label": f"{FIX_LABELS[f['action_type']]} on {names[f['account_id']]}"}
            for f in fixes
        ],
        "improvement": {
            "accounts_reachable": before["damage"]["accounts_reachable"] - after["damage"]["accounts_reachable"],
            "damage_score": before["damage"]["damage_score"] - after["damage"]["damage_score"],
            "financial_accounts": len(before["damage"]["financial_accounts_at_risk"])
            - len(after["damage"]["financial_accounts_at_risk"]),
        },
        "previous_run": None,
    }

