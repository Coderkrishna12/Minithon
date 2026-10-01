from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account, AccountConnection
from app.services.risk_engine import _load_network, score_network

DERIVED_TYPES = ("sso", "recovery_email", "password_reuse")

SSO_PROVIDERS = {
    "google": ("google", "gmail"),
    "apple": ("apple", "icloud"),
    "facebook": ("facebook",),
    "microsoft": ("microsoft", "outlook", "hotmail", "live.com"),
    "github": ("github",),
    "twitter": ("twitter", "x.com"),
}


def _identity(a: Account) -> str:
    return f"{a.service_name or ''} {a.service_url or ''}".lower()


def _norm(email: str | None) -> str:
    return (email or "").strip().lower()


def derive_edges(accounts: list[Account]) -> set[tuple[int, int, str]]:
    """Edges point from the account an attacker takes first to the account it unlocks."""
    edges: set[tuple[int, int, str]] = set()

    for a in accounts:
        method = (a.login_method or "").lower()
        provider = method.removesuffix("_sso") if method.endswith("_sso") else None
        if provider:
            keywords = SSO_PROVIDERS.get(provider, (provider,))
            for p in accounts:
                if p.id != a.id and any(k in _identity(p) for k in keywords):
                    edges.add((p.id, a.id, "sso"))

    mailboxes = [m for m in accounts if (m.category or "") == "email" and m.email_used]
    for a in accounts:
        reset_addresses = {_norm(a.recovery_email), _norm(a.email_used)} - {""}
        for m in mailboxes:
            if m.id != a.id and _norm(m.email_used) in reset_addresses:
                edges.add((m.id, a.id, "recovery_email"))

    groups: dict[str, list[Account]] = {}
    for a in accounts:
        if a.password_group:
            groups.setdefault(a.password_group, []).append(a)
    for members in groups.values():
        for i, x in enumerate(members):
            for y in members[i + 1:]:
                edges.add((x.id, y.id, "password_reuse"))

    return edges


async def refresh_user_graph(user_id: int, db: AsyncSession) -> None:
    """Rebuild derived connections from account data, then rescore every account."""
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = list(result.scalars().all())
    ids = [a.id for a in accounts]
    if ids:
        # Only write the difference: most refreshes change nothing, and rewriting every edge is slow.
        existing = (await db.execute(select(AccountConnection).where(
            AccountConnection.connection_type.in_(DERIVED_TYPES),
            AccountConnection.from_account_id.in_(ids) | AccountConnection.to_account_id.in_(ids),
        ))).scalars().all()
        wanted = derive_edges(accounts)
        have = {(e.from_account_id, e.to_account_id, e.connection_type): e for e in existing}
        stale = [e.id for key, e in have.items() if key not in wanted]
        if stale:
            await db.execute(delete(AccountConnection).where(AccountConnection.id.in_(stale)))
        db.add_all(
            AccountConnection(from_account_id=src, to_account_id=dst, connection_type=kind)
            for src, dst, kind in wanted - have.keys()
        )
        await db.flush()
        # Score the whole network once instead of reloading it for every account.
        _, connections, breaches = await _load_network(user_id, db)
        scores, components, _ = score_network(accounts, connections, breaches)
        for a in accounts:
            a.risk_score = scores.get(a.id, 0.0)
            a.risk_components = components.get(a.id, {})
    await db.commit()
