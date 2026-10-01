"""'Hack Me' attack simulator.

Starting from one compromised account, follow every way an attacker can move:
signing in through an SSO provider, resetting passwords via a recovery mailbox or
phone, replaying a reused password, or abusing device trust and data sharing.
Each hop has a success probability that depends on the target's 2FA, so the
simulation shows both where an attack spreads and where it gets stopped.

Deterministic and explainable: same inputs, same chain.
"""
from __future__ import annotations

import heapq
from dataclasses import dataclass, field

from app.services.risk_engine import ASSET_VALUE, _get

REACH_THRESHOLD = 0.15  # below this an account counts as defended
LIKELY_THRESHOLD = 0.5

# Chance that a hop works, by link type and the target's 2FA ("none" = known off, None = unknown).
HOP_SUCCESS = {
    # The attacker signs in as you through the provider; the target's own 2FA is usually bypassed.
    "sso": {"default": 0.85},
    # Password reset through your mailbox: strong 2FA on the target still asks for a code.
    "recovery_email": {"passkey": 0.05, "hardware": 0.05, "totp": 0.1, "sms": 0.5, "none": 0.9, None: 0.65},
    "recovery_phone": {"passkey": 0.05, "hardware": 0.05, "totp": 0.1, "sms": 0.6, "none": 0.9, None: 0.65},
    # Replaying a known password: any 2FA gets in the way.
    "password_reuse": {"passkey": 0.03, "hardware": 0.03, "totp": 0.08, "sms": 0.35, "none": 0.85, None: 0.6},
    "device_trust": {"default": 0.5},
    # Shared data leaks, but it does not hand over the account.
    "data_sharing": {"default": 0.3},
}
BIDIRECTIONAL = {"password_reuse"}
DATA_ONLY = {"data_sharing"}

HOW = {
    "sso": "signs in to {to} with \"Sign in with {from}\"",
    "recovery_email": "resets the {to} password from the {from} inbox",
    "recovery_phone": "intercepts the {to} reset code sent to the phone",
    "password_reuse": "tries the same password from {from} on {to}",
    "device_trust": "uses a device trusted by {from} to open {to}",
    "data_sharing": "reads data {from} shares with {to}",
}
BLOCKED_BY = {
    "passkey": "a passkey", "hardware": "a security key", "totp": "authenticator-app 2FA", "sms": "SMS 2FA",
}

# Typical attacker time per hop, in minutes (automated tooling; a SIM swap takes longer).
HOP_MINUTES = {
    "sso": 0.5, "password_reuse": 1.5, "recovery_email": 3, "recovery_phone": 45,
    "device_trust": 5, "data_sharing": 1,
}
# The entry account itself: typically a phished or leaked password.
ENTRY_MINUTES = 2

CONSEQUENCE = {
    "email": "Can read all of {s}'s mail and reset any password sent there",
    "finance": "Can reset {s} and move your money",
    "social": "Can message your friends from {s} as you, the classic scam setup",
    "cloud": "Can download every file and photo in {s}",
    "shopping": "Can order on {s} with your saved card to their own address",
    "work": "Can get into your work through {s}",
    "gaming": "Can spend on {s} and sell the account",
    "entertainment": "Can use {s} and see your payment details",
    "productivity": "Can read your documents in {s}",
}

DATA_BY_CATEGORY = {
    "email": ["Emails", "Contacts", "Password reset links"],
    "finance": ["Bank & card details", "Transactions", "Ability to move money"],
    "social": ["Private messages", "Photos", "Friends list"],
    "cloud": ["Files & backups", "Photos"],
    "shopping": ["Home address", "Order history", "Saved cards"],
    "work": ["Work documents", "Colleague contacts"],
    "productivity": ["Documents", "Calendar"],
    "gaming": ["Payment methods", "Chat history"],
    "entertainment": ["Viewing history", "Payment methods"],
}
DATA_BY_PERMISSION = {
    "location": "Location history", "contacts": "Contacts", "camera": "Camera access",
    "microphone": "Microphone access", "sms": "Text messages", "call_logs": "Call history",
    "storage": "Phone storage", "phone": "Phone number", "health": "Health data",
}


def _twofa(account) -> str | None:
    method = (_get(account, "twofa_method") or "").lower() or None
    has = _get(account, "has_2fa")
    if method in ("passkey", "hardware", "totp", "sms"):
        return method
    if has is True:
        return "totp"  # 2FA confirmed, method unknown: assume an authenticator app
    if has is False:
        return "none"
    return None


def hop_success(kind: str, target) -> float:
    table = HOP_SUCCESS.get(kind, {"default": 0.3})
    if "default" in table:
        return table["default"]
    return table.get(_twofa(target), table[None])


def likelihood(probability: float) -> str:
    if probability >= LIKELY_THRESHOLD:
        return "likely"
    if probability >= REACH_THRESHOLD:
        return "possible"
    return "unlikely"


@dataclass
class Simulation:
    entry_id: int
    reached: dict[int, float] = field(default_factory=dict)
    parent: dict[int, tuple[int, str]] = field(default_factory=dict)
    hops: dict[int, int] = field(default_factory=dict)
    blocked: list[dict] = field(default_factory=list)


def _adjacency(connections) -> dict[int, list[tuple[int, str]]]:
    adj: dict[int, list[tuple[int, str]]] = {}
    seen = set()
    for c in connections:
        src, dst, kind = _get(c, "from_account_id"), _get(c, "to_account_id"), _get(c, "connection_type")
        pairs = [(src, dst)] + ([(dst, src)] if kind in BIDIRECTIONAL else [])
        for a, b in pairs:
            if a != b and (a, b, kind) not in seen:
                seen.add((a, b, kind))
                adj.setdefault(a, []).append((b, kind))
    return adj


def simulate(accounts, connections, entry_id: int) -> Simulation:
    """Best-first search for the most likely way to reach every account from the entry point."""
    by_id = {_get(a, "id"): a for a in accounts}
    adj = _adjacency(connections)
    sim = Simulation(entry_id=entry_id)
    sim.reached[entry_id], sim.hops[entry_id] = 1.0, 0
    heap = [(-1.0, 0, entry_id)]
    done = set()
    attempts: dict[int, dict] = {}
    while heap:
        neg, hops, node = heapq.heappop(heap)
        if node in done:
            continue
        done.add(node)
        prob = -neg
        if _get(by_id[node], "id") != entry_id and sim.parent[node][1] in DATA_ONLY:
            continue  # data exposure only: the attacker can't act from here
        for target, kind in adj.get(node, []):
            if target not in by_id or target == entry_id:
                continue
            step = hop_success(kind, by_id[target])
            candidate = prob * step
            if candidate >= REACH_THRESHOLD and candidate > sim.reached.get(target, 0.0) + 1e-9:
                sim.reached[target] = candidate
                sim.parent[target] = (node, kind)
                sim.hops[target] = hops + 1
                heapq.heappush(heap, (-candidate, hops + 1, target))
            elif candidate < REACH_THRESHOLD and prob >= REACH_THRESHOLD:
                # Remember the strongest stopped attempt per target, in case nothing else gets there.
                best = attempts.get(target)
                if not best or candidate > best["probability"]:
                    attempts[target] = {"from_id": node, "to_id": target, "via": kind, "probability": candidate,
                                        "hop_success": step, "hop": hops + 1}
    sim.blocked = [a for t, a in attempts.items() if t not in sim.reached]
    return sim


def report(accounts, sim: Simulation, breaches=()) -> dict:
    by_id = {_get(a, "id"): a for a in accounts}
    name = lambda aid: _get(by_id[aid], "service_name")  # noqa: E731

    def node(aid: int) -> dict:
        a = by_id[aid]
        return {"id": aid, "service": _get(a, "service_name"), "category": _get(a, "category") or "other",
                "twofa": _twofa(a)}

    def elapsed(aid: int) -> float:
        total, node = 0.0, aid
        while node != sim.entry_id:
            src, kind = sim.parent[node]
            total += HOP_MINUTES.get(kind, 5)
            node = src
        return ENTRY_MINUTES + total

    steps = []
    for aid in sorted((x for x in sim.reached if x != sim.entry_id), key=lambda x: (sim.hops[x], -sim.reached[x])):
        src, kind = sim.parent[aid]
        prob = sim.reached[aid]
        steps.append({
            "order": len(steps) + 1,
            "hop": sim.hops[aid],
            "from_id": src,
            "to_id": aid,
            "from": name(src),
            "to": name(aid),
            "via": kind,
            "hop_success": round(hop_success(kind, by_id[aid]), 2),
            "probability": round(prob, 3),
            "likelihood": likelihood(prob),
            "data_only": kind in DATA_ONLY,
            "explanation": "The attacker " + HOW.get(kind, "moves from {from} to {to}").format(**{"from": name(src), "to": name(aid)}),
            "minutes": HOP_MINUTES.get(kind, 5),
            "elapsed_minutes": round(elapsed(aid), 1),
        })
    # Play back in the order an attacker would actually get there.
    steps.sort(key=lambda s: (s["elapsed_minutes"], s["hop"]))
    for i, s in enumerate(steps, 1):
        s["order"] = i

    blocked = []
    for b in sorted(sim.blocked, key=lambda b: -b["probability"]):
        target = by_id[b["to_id"]]
        defence = BLOCKED_BY.get(_twofa(target), "low odds on this link")
        blocked.append({
            **{k: b[k] for k in ("from_id", "to_id", "via", "hop")},
            "elapsed_minutes": round(elapsed(b["from_id"]) + HOP_MINUTES.get(b["via"], 5), 1),
            "from": name(b["from_id"]), "to": name(b["to_id"]),
            "probability": round(b["probability"], 3),
            "explanation": f"Stopped at {name(b['to_id'])}: {defence} blocks the "
            + {"recovery_email": "password reset", "recovery_phone": "reset code", "password_reuse": "reused password",
               "sso": "SSO sign-in"}.get(b["via"], "attempt"),
        })

    compromised = [aid for aid, p in sim.reached.items() if aid != sim.entry_id]
    takeovers = [s for s in steps if not s["data_only"]]
    exposed: dict[str, set[str]] = {}
    for aid in [sim.entry_id, *compromised]:
        a = by_id[aid]
        for item in DATA_BY_CATEGORY.get((_get(a, "category") or "").lower(), ["Profile details"]):
            exposed.setdefault(item, set()).add(_get(a, "service_name"))
        for perm in _get(a, "permissions", []) or []:
            label = DATA_BY_PERMISSION.get(str(perm).lower())
            if label:
                exposed.setdefault(label, set()).add(_get(a, "service_name"))
    breached_ids = {_get(b, "account_id") for b in breaches}

    total_value = sum(ASSET_VALUE.get((_get(a, "category") or "other").lower(), 0.3) for a in accounts) or 1
    at_risk_value = sum(
        ASSET_VALUE.get((_get(by_id[aid], "category") or "other").lower(), 0.3) * sim.reached[aid]
        for aid in sim.reached
    )
    finance = [aid for aid in sim.reached if (_get(by_id[aid], "category") or "") == "finance"]
    return {
        "entry": {**node(sim.entry_id), "breached": sim.entry_id in breached_ids},
        "nodes": [
            {**node(aid), "status": "entry" if aid == sim.entry_id else (
                "compromised" if aid in sim.reached and sim.parent[aid][1] not in DATA_ONLY
                else "data_exposed" if aid in sim.reached else "blocked" if aid in {b["to_id"] for b in blocked}
                else "safe"),
             "hop": sim.hops.get(aid),
             "probability": round(sim.reached.get(aid, 0.0), 3)}
            for aid in by_id
        ],
        "steps": steps,
        "blocked": blocked,
        "damage": {
            "accounts_reachable": len(compromised),
            "accounts_taken_over": len(takeovers),
            "likely": sum(1 for s in steps if s["likelihood"] == "likely"),
            "possible": sum(1 for s in steps if s["likelihood"] == "possible"),
            "total_accounts": len(accounts),
            "max_hops": max((s["hop"] for s in steps), default=0),
            "damage_score": round(min(100.0, at_risk_value / total_value * 100)),
            "financial_accounts_at_risk": [
                {"id": aid, "service": name(aid), "probability": round(sim.reached[aid], 3)} for aid in finance
            ],
            "data_exposed": [
                {"type": k, "services": sorted(v)} for k, v in sorted(exposed.items(), key=lambda kv: -len(kv[1]))
            ],
            "attacks_blocked": len(blocked),
            "time_to_full_takeover_minutes": max((s["elapsed_minutes"] for s in steps), default=ENTRY_MINUTES),
            "consequences": [
                CONSEQUENCE.get((_get(by_id[aid], "category") or "").lower(), "Can take over {s}").format(
                    s=_get(by_id[aid], "service_name"))
                for aid in sorted([sim.entry_id, *compromised],
                                  key=lambda x: -ASSET_VALUE.get((_get(by_id[x], "category") or "other").lower(), 0.3))
                if aid == sim.entry_id or sim.parent[aid][1] not in DATA_ONLY
            ][:6],
        },
    }


def apply_fixes(accounts, connections, fixes) -> tuple[list[dict], list[dict]]:
    """Copy the network with fix actions applied, mirroring what completing each fix records."""
    by_account: dict[int, set[str]] = {}
    for f in fixes:
        by_account.setdefault(_get(f, "account_id"), set()).add(_get(f, "action_type"))
    fixed_reuse = {aid for aid, kinds in by_account.items() if "change_password" in kinds}
    cloned = []
    for a in accounts:
        item = {k: _get(a, k) for k in (
            "id", "service_name", "category", "has_2fa", "twofa_method", "password_group", "breach_count", "risk_score",
        )}
        item["permissions"] = list(_get(a, "permissions", []) or [])
        kinds = by_account.get(item["id"], set())
        if "enable_2fa" in kinds:
            item["has_2fa"], item["twofa_method"] = True, "totp"
        if "change_password" in kinds:
            item["password_group"] = None
        if "revoke_permission" in kinds:
            item["permissions"] = []
        cloned.append(item)
    edges = [
        {k: _get(c, k) for k in ("from_account_id", "to_account_id", "connection_type")}
        for c in connections
        if not (_get(c, "connection_type") == "password_reuse"
                and ({_get(c, "from_account_id"), _get(c, "to_account_id")} & fixed_reuse))
    ]
    return cloned, edges


def blast_counts(accounts, connections) -> dict[int, tuple[int, float]]:
    """For each possible entry point: accounts exposed, and their value weighted by how likely each hop is."""
    out = {}
    for a in accounts:
        sim = simulate(accounts, connections, _get(a, "id"))
        others = [aid for aid in sim.reached if aid != sim.entry_id]
        by_id = {_get(x, "id"): x for x in accounts}
        weighted = sum(ASSET_VALUE.get((_get(by_id[aid], "category") or "other").lower(), 0.3) * sim.reached[aid]
                       for aid in others)
        out[_get(a, "id")] = (len(others), weighted)
    return out


def default_fixes(accounts) -> list[dict]:
    """The fixes PrivacyShield recommends: 2FA everywhere it's missing, and no reused passwords."""
    fixes = []
    for a in accounts:
        if _get(a, "has_2fa") is not True:
            fixes.append({"id": None, "account_id": _get(a, "id"), "action_type": "enable_2fa"})
        if _get(a, "password_group"):
            fixes.append({"id": None, "account_id": _get(a, "id"), "action_type": "change_password"})
    return fixes


# A made-up but typical person, so the simulator can be tried without touching real data.
DEMO_ACCOUNTS = [
    {"id": 1, "service_name": "Gmail", "category": "email", "has_2fa": False, "password_group": "dog-name-2019",
     "permissions": ["contacts"]},
    {"id": 2, "service_name": "Outlook", "category": "email", "has_2fa": False, "password_group": "dog-name-2019"},
    {"id": 3, "service_name": "PayPal", "category": "finance", "has_2fa": False},
    {"id": 4, "service_name": "HDFC NetBanking", "category": "finance", "has_2fa": True, "twofa_method": "sms"},
    {"id": 5, "service_name": "Instagram", "category": "social", "has_2fa": False, "password_group": "dog-name-2019",
     "permissions": ["location", "camera", "contacts"]},
    {"id": 6, "service_name": "WhatsApp Web", "category": "social", "has_2fa": False},
    {"id": 7, "service_name": "Google Drive", "category": "cloud", "has_2fa": False},
    {"id": 8, "service_name": "Amazon", "category": "shopping", "has_2fa": False, "password_group": "dog-name-2019"},
    {"id": 9, "service_name": "Flipkart", "category": "shopping", "has_2fa": False},
    {"id": 10, "service_name": "Spotify", "category": "entertainment", "has_2fa": None},
    {"id": 11, "service_name": "Canva", "category": "productivity", "has_2fa": None, "password_group": "dog-name-2019"},
    {"id": 12, "service_name": "GitHub", "category": "work", "has_2fa": True, "twofa_method": "totp"},
]
DEMO_EDGES = [
    {"from_account_id": a, "to_account_id": b, "connection_type": kind}
    for a, b, kind in [
        (1, 3, "recovery_email"), (1, 4, "recovery_email"), (1, 7, "sso"), (1, 10, "sso"), (1, 9, "recovery_email"),
        (1, 12, "recovery_email"), (2, 8, "recovery_email"), (1, 6, "device_trust"), (5, 6, "data_sharing"),
        (1, 2, "password_reuse"), (1, 5, "password_reuse"), (1, 8, "password_reuse"), (1, 11, "password_reuse"),
        (2, 5, "password_reuse"), (5, 8, "password_reuse"), (8, 11, "password_reuse"),
    ]
]
DEMO_BREACHES = [{"account_id": 11, "breach_name": "Canva", "data_exposed": ["email", "password"]}]
