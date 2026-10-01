import html
import re
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account, AccountConnection, BreachRecord, DarkWebAlert, FixAction

USER_SOURCE_TYPES = {"overview", "account", "breach", "exposure", "fix"}
CATALOG_SOURCE_TYPE = "hibp_breach"
POLICY_SOURCE_TYPE = "policy"

SOURCE_LABELS = {
    "overview": "Your risk overview",
    "account": "Your account",
    "breach": "Breach on your account",
    "exposure": "Dark web exposure",
    "fix": "Recommended fix",
    "policy": "Privacy policy",
    CATALOG_SOURCE_TYPE: "Have I Been Pwned",
}

EDGE_PHRASES = {
    "sso": "signs in through",
    "recovery_email": "sends password resets to",
    "password_reuse": "shares a password with",
    "data_sharing": "shares data with",
}


@dataclass
class SourceDoc:
    source_type: str
    source_id: str
    title: str
    text: str
    url: str | None = None


def strip_html(value: str | None) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", value or ""))).strip()


async def user_documents(user_id: int, db: AsyncSession) -> list[SourceDoc]:
    """Everything PrivacyShield knows about this user, written as plain-language records."""
    accounts = list((await db.execute(select(Account).where(Account.user_id == user_id))).scalars().all())
    by_id = {a.id: a for a in accounts}
    ids = list(by_id)

    edges = []
    breaches = []
    if ids:
        edges = (await db.execute(select(AccountConnection).where(AccountConnection.from_account_id.in_(ids)))).scalars().all()
        breaches = (await db.execute(select(BreachRecord).where(BreachRecord.account_id.in_(ids)))).scalars().all()
    alerts = (await db.execute(select(DarkWebAlert).where(DarkWebAlert.user_id == user_id))).scalars().all()
    fixes = (await db.execute(
        select(FixAction).where(FixAction.user_id == user_id, FixAction.status == "pending")
    )).scalars().all()

    docs: list[SourceDoc] = []
    if accounts:
        ranked = sorted(accounts, key=lambda a: -(a.risk_score or 0))
        reach = {a.id: sum(1 for e in edges if e.from_account_id == a.id) for a in accounts}
        hub = max(accounts, key=lambda a: reach[a.id])
        groups: dict[str, list[str]] = {}
        for a in accounts:
            if a.password_group:
                groups.setdefault(a.password_group, []).append(a.service_name)
        reused = [names for names in groups.values() if len(names) > 1]
        no_2fa = [a.service_name for a in accounts if not a.has_2fa]
        overview = [
            f"Biggest risks and overall summary: you track {len(accounts)} accounts, {len(breaches)} breach record(s), "
            f"{sum(1 for x in alerts if not x.is_resolved)} unresolved exposure(s) and {len(fixes)} pending fix(es).",
            "Highest risk first: " + ", ".join(f"{a.service_name} {a.risk_score:.0f}" for a in ranked[:5]) + ".",
            f"Without two-factor authentication: {', '.join(no_2fa) or 'none'}.",
        ]
        if reused:
            overview.append("Password reused across: " + "; ".join(", ".join(n) for n in reused) + ".")
        if reach[hub.id]:
            overview.append(f"Single point of failure: {hub.service_name} unlocks {reach[hub.id]} other account(s).")
        docs.append(SourceDoc("overview", "summary", "Your risk overview", " ".join(overview)))

    for a in accounts:
        unlocks = [f"{EDGE_PHRASES.get(e.connection_type, e.connection_type)}: {by_id[e.to_account_id].service_name}"
                   for e in edges if e.from_account_id == a.id and e.to_account_id in by_id]
        unlocked_by = [f"{by_id[e.from_account_id].service_name} ({e.connection_type.replace('_', ' ')})"
                       for e in edges if e.to_account_id == a.id and e.from_account_id in by_id]
        same_password = [o.service_name for o in accounts if o.id != a.id and a.password_group and o.password_group == a.password_group]
        lines = [
            f"{a.service_name} ({a.service_url or 'no URL'}) is a {a.category or 'uncategorised'} account.",
            f"Signed up with {a.email_used or 'an unknown email'}; logs in with {(a.login_method or 'password').replace('_', ' ')}.",
            f"Two-factor authentication is {'on' if a.has_2fa else 'OFF'}.",
            f"Risk score {a.risk_score:.0f}/100; {a.breach_count or 0} known breach(es).",
        ]
        if same_password:
            lines.append(f"Uses the same password as: {', '.join(same_password)}.")
        if a.recovery_email:
            lines.append(f"Recovery email: {a.recovery_email}.")
        if a.permissions:
            lines.append(f"Granted permissions: {', '.join(a.permissions)}.")
        if unlocked_by:
            lines.append(f"Can be taken over through: {', '.join(unlocked_by)}.")
        if unlocks:
            lines.append(f"If compromised, an attacker can reach accounts it {'; '.join(unlocks)}.")
        docs.append(SourceDoc("account", str(a.id), f"Account: {a.service_name}", " ".join(lines)))

    for b in breaches:
        account = by_id.get(b.account_id)
        confirmed = b.source in ("hibp_account", "xposedornot")
        when = b.breach_date.date().isoformat() if b.breach_date else "an unknown date"
        text = (
            f"{b.breach_name} breach on {when} affects your {account.service_name if account else 'unknown'} account. "
            + ("Your email address was confirmed in the leaked data. " if confirmed
               else "The service was breached; it is not confirmed that your account was in the leak. ")
            + f"Data exposed: {', '.join(b.data_exposed or []) or 'not specified'}. Source: {b.source}."
        )
        docs.append(SourceDoc("breach", str(b.id), f"Breach: {b.breach_name} ({account.service_name if account else 'unknown'})", text))

    for alert in alerts:
        docs.append(SourceDoc(
            "exposure", str(alert.id), f"Exposure: {alert.source}",
            f"{alert.data_found}. Type: {alert.alert_type.replace('_', ' ')}; severity {alert.severity}; "
            f"{'resolved' if alert.is_resolved else 'unresolved'}.",
        ))

    for f in fixes:
        target = by_id.get(f.account_id)
        docs.append(SourceDoc(
            "fix", str(f.id), f"Fix: {f.action_type.replace('_', ' ')}{' on ' + target.service_name if target else ''}",
            f"{f.description} Priority {f.priority}; removes about {f.risk_reduction:.0f} points of risk.",
        ))
    return docs


def catalog_documents(catalog: list[dict]) -> list[SourceDoc]:
    """Every public breach in Have I Been Pwned, so PrivacyBot can explain any breach by name."""
    docs = []
    for b in catalog:
        name = b.get("Name")
        if not name:
            continue
        title = b.get("Title") or name
        flags = [label for key, label in (("IsVerified", "verified"), ("IsSensitive", "sensitive"), ("IsRetired", "retired")) if b.get(key)]
        text = (
            f"{title} ({b.get('Domain') or 'no domain'}) was breached on {b.get('BreachDate') or 'an unknown date'}, "
            f"exposing {b.get('PwnCount') or 0:,} accounts. Compromised data: {', '.join(b.get('DataClasses') or []) or 'unspecified'}. "
            f"{'Flags: ' + ', '.join(flags) + '. ' if flags else ''}{strip_html(b.get('Description'))}"
        )
        docs.append(SourceDoc(CATALOG_SOURCE_TYPE, name, f"{title} breach", text, f"https://haveibeenpwned.com/PwnedWebsites#{name}"))
    return docs


def policy_document(url: str, text: str) -> SourceDoc:
    return SourceDoc(POLICY_SOURCE_TYPE, url, f"Privacy policy: {url}", text, url)
