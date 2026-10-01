"""Deterministic, explainable risk model used as the score source of truth.

Component scales and connection probabilities are versioned so every preview and
completion can be recomputed from the same inputs. No trained model is claimed.
"""
from __future__ import annotations

from collections import defaultdict, deque
from datetime import datetime, timezone
from math import log2

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account, AccountConnection, BreachRecord, FixAction
from app.models.user import User

MODEL_VERSION = "deterministic-2"
EDGE_PROBABILITY = {
    "recovery_email": 0.90,
    "recovery_phone": 0.90,
    "sso": 0.85,
    "password_reuse": 0.80,
    "device_trust": 0.50,
    "data_sharing": 0.30,
}
ASSET_VALUE = {"finance": 1.0, "email": 0.9, "cloud": 0.7, "social": 0.5, "other": 0.3}
PERMISSION_WEIGHT = {
    "camera": 15, "microphone": 15, "location": 15, "contacts": 10,
    "storage": 8, "sms": 20, "call_logs": 18, "phone": 12,
}


def _get(obj, name, default=None):
    return obj.get(name, default) if isinstance(obj, dict) else getattr(obj, name, default)


def _asset(account) -> float:
    return ASSET_VALUE.get((_get(account, "category") or "other").lower(), 0.3)


def _connections_for(accounts, connections):
    ids = {_get(a, "id") for a in accounts}
    return [c for c in connections if _get(c, "from_account_id") in ids and _get(c, "to_account_id") in ids]


def _blast(accounts, connections):
    """Return normalized radius, reachable IDs, and best decayed path probability."""
    adjacency = defaultdict(list)
    for edge in connections:
        source, target = _get(edge, "from_account_id"), _get(edge, "to_account_id")
        if source != target:
            weight = EDGE_PROBABILITY.get(_get(edge, "connection_type"), 0.3)
            adjacency[source].append((target, weight))
    by_id = {_get(a, "id"): a for a in accounts}
    total_assets = sum(_asset(a) for a in accounts)
    scores, reachable, paths = {}, {}, {}
    for source in by_id:
        max_radius = max(total_assets - _asset(by_id[source]), 0.1)
        best = {source: 1.0}
        queue = deque([(source, 1.0, 0)])
        while queue:
            node, probability, hops = queue.popleft()
            for target, edge_weight in adjacency[node]:
                candidate = probability * edge_weight * (0.7 if hops >= 0 else 1.0)
                if candidate > best.get(target, 0.0) + 1e-9:
                    best[target] = candidate
                    queue.append((target, candidate, hops + 1))
        reached = {key: val for key, val in best.items() if key != source and val > 0}
        radius = sum(_asset(by_id[aid]) * prob for aid, prob in reached.items())
        scores[source] = min(100.0, radius / max_radius * 100)
        reachable[source] = reached
        paths[source] = sorted(reached.items(), key=lambda item: item[1] * _asset(by_id[item[0]]), reverse=True)
    return scores, reachable, paths


def _breach_score(account, breach_records):
    records = breach_records.get(_get(account, "id"), [])
    if not records:
        return min(100.0, float(_get(account, "breach_count", 0) or 0) * 20.0)
    now = datetime.now(timezone.utc)
    points = 0.0
    for record in records:
        exposed = {str(x).lower().replace(" ", "_") for x in (_get(record, "data_exposed", []) or [])}
        severity = 1.6 if exposed & {"password", "passwords", "auth_token", "access_token"} else 1.0
        date = _get(record, "breach_date")
        if date:
            if date.tzinfo is None:
                date = date.replace(tzinfo=timezone.utc)
            age_years = max(0.0, (now - date).days / 365.25)
            recency = max(0.2, 1.0 - age_years / 10.0)
        else:
            recency = 0.6
        points += 25.0 * severity * recency
    return min(100.0, points)


def score_network(accounts, connections, breach_records=()):
    """Compute per-account explainable risk and network privacy score."""
    breaches = defaultdict(list)
    for record in breach_records:
        breaches[_get(record, "account_id")].append(record)
    reuse_counts = defaultdict(int)
    for account in accounts:
        group = _get(account, "password_group")
        if group:
            reuse_counts[group] += 1
    radius, reachable, paths = _blast(accounts, _connections_for(accounts, connections))
    risk_by_id, components_by_id = {}, {}
    for account in accounts:
        aid = _get(account, "id")
        method = (_get(account, "twofa_method") or "").lower()
        twofa = _get(account, "has_2fa")
        missing_2fa = {"passkey": 0, "hardware": 0, "totp": 20, "sms": 60}.get(
            method, 0 if twofa is True else 100 if twofa is False else 50
        )
        permissions = {str(p).lower() for p in (_get(account, "permissions", []) or [])}
        permission = min(100.0, sum(PERMISSION_WEIGHT.get(p, 0) for p in permissions))
        reuse_size = reuse_counts.get(_get(account, "password_group"), 0)
        reuse = min(100.0, log2(max(1, reuse_size)) * 45.0 + (15.0 if _get(account, "password_group") else 0))
        breach = _breach_score(account, breaches)
        cascade = radius.get(aid, 0.0)
        base = 0.30 * breach + 0.20 * permission + 0.20 * reuse + 0.15 * missing_2fa + 0.15 * cascade
        reached = reachable.get(aid, {})
        is_keystone = len(reached) >= 5
        # Stronger authentication lowers, but does not erase, a verified keystone risk.
        keystone_floor = 60.0 if twofa is True else 75.0
        final = max(base, keystone_floor) if is_keystone else base
        components_by_id[aid] = {
            "model_version": MODEL_VERSION,
            "breach": round(breach, 2),
            "permission_scope": round(permission, 2),
            "password_reuse": round(reuse, 2),
            "missing_2fa": round(missing_2fa, 2),
            "cascading_impact": round(cascade, 2),
            "base_score": round(min(100.0, base), 2),
            "keystone": is_keystone,
            "reachable_accounts": len(reached),
            "keystone_floor": keystone_floor if is_keystone else None,
            "top_paths": [
                {"account_id": target, "probability": round(prob, 4)}
                for target, prob in paths.get(aid, [])[:5]
            ],
        }
        risk_by_id[aid] = min(100.0, final)
    if not accounts:
        return risk_by_id, components_by_id, 100
    weights = [
        _asset(a) * (1 + radius.get(_get(a, "id"), 0.0) / 100.0)
        for a in accounts
    ]
    weighted = sum(risk_by_id[_get(a, "id")] * w for a, w in zip(accounts, weights)) / max(sum(weights), 1e-9)
    unmitigated_keystones = sum(
        1 for a in accounts
        if components_by_id[_get(a, "id")]["keystone"] and _get(a, "has_2fa") is not True
    )
    privacy_score = max(0, min(100, round(100 - weighted - unmitigated_keystones * 5)))
    return risk_by_id, components_by_id, privacy_score


async def _load_network(user_id: int, db: AsyncSession):
    accounts = list((await db.execute(select(Account).where(Account.user_id == user_id))).scalars().all())
    ids = [a.id for a in accounts]
    if not ids:
        return accounts, [], []
    connections = list((await db.execute(select(AccountConnection).where(
        AccountConnection.from_account_id.in_(ids), AccountConnection.to_account_id.in_(ids)
    ))).scalars().all())
    breaches = list((await db.execute(select(BreachRecord).where(BreachRecord.account_id.in_(ids)))).scalars().all())
    return accounts, connections, breaches


async def calculate_account_risk(account: Account, db: AsyncSession) -> float:
    accounts, connections, breaches = await _load_network(account.user_id, db)
    scores, details, _ = score_network(accounts, connections, breaches)
    account.risk_components = details.get(account.id, {})
    return scores.get(account.id, 0.0)


async def calculate_privacy_score(user_id: int, db: AsyncSession) -> int:
    accounts, connections, breaches = await _load_network(user_id, db)
    scores, components, privacy_score = score_network(accounts, connections, breaches)
    for account in accounts:
        account.risk_score = scores[account.id]
        account.risk_components = components[account.id]
    await db.commit()
    return privacy_score


async def find_single_points_of_failure(user_id: int, db: AsyncSession) -> list[Account]:
    accounts, connections, breaches = await _load_network(user_id, db)
    _, components, _ = score_network(accounts, connections, breaches)
    return sorted(
        (a for a in accounts if components[a.id]["reachable_accounts"] >= 3),
        key=lambda a: (components[a.id]["reachable_accounts"], a.risk_score),
        reverse=True,
    )[:3]


async def generate_fix_actions(user_id: int, db: AsyncSession) -> list[FixAction]:
    accounts, connections, breaches = await _load_network(user_id, db)
    score_by_id, _, current_score = score_network(accounts, connections, breaches)
    actions = []
    for account in accounts:
        candidates = []
        if account.has_2fa is not True:
            candidates.append(("enable_2fa", "Enable two-factor authentication", 10))
        if account.password_group:
            candidates.append(("change_password", "Replace the reused password with a unique password", 15))
        unnecessary = [p for p in (account.permissions or []) if str(p).lower() in PERMISSION_WEIGHT]
        if unnecessary:
            candidates.append(("revoke_permission", "Review and revoke permissions you do not need", 8))
        for action_type, label, minutes in candidates:
            changed = []
            for item in accounts:
                clone = {
                    "id": item.id, "category": item.category, "has_2fa": item.has_2fa,
                    "twofa_method": item.twofa_method, "permissions": list(item.permissions or []),
                    "password_group": item.password_group, "breach_count": item.breach_count,
                    "risk_score": item.risk_score,
                }
                if item.id == account.id:
                    if action_type == "enable_2fa":
                        clone["has_2fa"], clone["twofa_method"] = True, "totp"
                    elif action_type == "change_password":
                        clone["password_group"] = None
                    elif action_type == "revoke_permission":
                        clone["permissions"] = []
                changed.append(clone)
            changed_edges = [
                {"from_account_id": e.from_account_id, "to_account_id": e.to_account_id,
                 "connection_type": e.connection_type}
                for e in connections
                if not (action_type == "change_password" and e.connection_type == "password_reuse"
                        and account.id in (e.from_account_id, e.to_account_id))
            ]
            new_scores, _, new_network_score = score_network(changed, changed_edges, breaches)
            reduction = max(0, new_network_score - current_score)
            if reduction <= 0:
                continue
            actions.append(FixAction(
                user_id=user_id, account_id=account.id, action_type=action_type,
                description=f"{label} on {account.service_name}",
                priority=round(reduction * 100 / minutes), risk_reduction=float(reduction), status="pending",
            ))
    actions.sort(key=lambda item: (item.priority, item.risk_reduction), reverse=True)
    return actions
