import asyncio
import copy
import time
from datetime import datetime, timezone
from urllib.parse import quote, urlparse

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.account import Account, BreachRecord, Notification
from app.services.connections import refresh_user_graph
from app.services.integration_status import record_call

settings = get_settings()

HIBP_API = "https://haveibeenpwned.com/api/v3"
XON_API = "https://api.xposedornot.com/v1"
USER_AGENT = "PrivacyShield/1.0"
CATALOG_TTL_SECONDS = 6 * 3600
ACCOUNT_SOURCES = {"hibp_account", "xposedornot"}
MOCK_CATALOG = [
    {"Name": "ExampleForum", "Title": "Example Forum (Demo)", "Domain": "example.invalid",
     "BreachDate": "2024-01-15", "PwnCount": 12000,
     "DataClasses": ["Email addresses", "Passwords"], "IsFabricated": False},
]
MOCK_EMAIL = "demo@privacyshield.test"

_catalog: list[dict] = []
_catalog_fetched_at = 0.0
_catalog_lock = asyncio.Lock()
_hibp_lock = asyncio.Lock()
_hibp_last_call = 0.0


def http_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(timeout=15, headers={"user-agent": USER_AGENT})


def normalize_domain(value: str | None) -> str:
    if not value:
        return ""
    v = value.strip().lower()
    host = urlparse(v if "://" in v else f"//{v}").hostname or ""
    return host.removeprefix("www.")


def _domain_matches(account_domain: str, breach_domain: str) -> bool:
    return bool(account_domain and breach_domain) and (
        account_domain == breach_domain or account_domain.endswith("." + breach_domain)
    )


def _parse_date(value: str | None) -> datetime | None:
    if not value or len(value) < 10:
        return None
    try:
        return datetime.fromisoformat(value[:10]).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _from_hibp(b: dict, source: str) -> dict:
    return {
        "name": b.get("Title") or b.get("Name"),
        "domain": (b.get("Domain") or "").lower(),
        "date": b.get("BreachDate"),
        "data": b.get("DataClasses") or [],
        "records": b.get("PwnCount"),
        "source": source,
    }


async def _hibp_keyed_get(client: httpx.AsyncClient, path: str, **params) -> httpx.Response:
    """Keyed HIBP endpoints are rate limited per key; space calls to stay under settings.hibp_rpm."""
    global _hibp_last_call
    async with _hibp_lock:
        wait = 60 / max(settings.hibp_rpm, 1) - (time.monotonic() - _hibp_last_call)
        if wait > 0:
            await asyncio.sleep(wait)
        _hibp_last_call = time.monotonic()
        return await client.get(f"{HIBP_API}{path}", params=params or None, headers={"hibp-api-key": settings.hibp_api_key})


async def get_breach_catalog(client: httpx.AsyncClient) -> list[dict]:
    """Every public breach HIBP knows about. Free, no key required."""
    global _catalog, _catalog_fetched_at
    if settings.hibp_mode.lower() == "mock":
        record_call("hibp", healthy=True, detail="Deterministic demo fixture")
        return copy.deepcopy(MOCK_CATALOG)
    async with _catalog_lock:
        if _catalog and time.monotonic() - _catalog_fetched_at < CATALOG_TTL_SECONDS:
            return _catalog
        started = time.monotonic()
        try:
            resp = await client.get(f"{HIBP_API}/breaches")
            resp.raise_for_status()
        except httpx.HTTPError as exc:
            record_call("hibp", healthy=False, latency_ms=(time.monotonic() - started) * 1000,
                        detail=type(exc).__name__)
            raise
        record_call("hibp", healthy=True, latency_ms=(time.monotonic() - started) * 1000)
        _catalog = [b for b in resp.json() if not b.get("IsFabricated") and not b.get("IsSpamList")]
        _catalog_fetched_at = time.monotonic()
        return _catalog


def service_breaches(catalog: list[dict], account: Account) -> list[dict]:
    domain = normalize_domain(account.service_url)
    name = (account.service_name or "").strip().lower()
    found = []
    for b in catalog:
        names = {(b.get("Name") or "").lower(), (b.get("Title") or "").lower()}
        if _domain_matches(domain, (b.get("Domain") or "").lower()) or (name and name in names):
            found.append(_from_hibp(b, "hibp_catalog"))
    return found


async def email_breaches(client: httpx.AsyncClient, email: str) -> tuple[list[dict], str]:
    """Breaches this exact email appears in. HIBP when a key is configured, otherwise XposedOrNot."""
    if settings.xon_mode.lower() == "mock" or settings.hibp_mode.lower() == "mock":
        record_call("xon", healthy=True, detail="Deterministic demo fixture")
        if email.strip().lower() == MOCK_EMAIL:
            return ([{"name": "Example Forum (Demo)", "domain": "example.invalid",
                      "date": "2024-01-15", "data": ["email addresses", "passwords"],
                      "records": 12000, "source": "xposedornot"}], "mock")
        return [], "mock"
    if settings.hibp_api_key:
        started = time.monotonic()
        try:
            resp = await _hibp_keyed_get(client, f"/breachedaccount/{quote(email)}", truncateResponse="false")
            resp.raise_for_status() if resp.status_code != 404 else None
        except httpx.HTTPError as exc:
            record_call("hibp", healthy=False, latency_ms=(time.monotonic() - started) * 1000,
                        detail=type(exc).__name__)
            raise
        record_call("hibp", healthy=True, latency_ms=(time.monotonic() - started) * 1000)
        if resp.status_code == 404:
            return [], "hibp"
        return [_from_hibp(b, "hibp_account") for b in resp.json()], "hibp"

    started = time.monotonic()
    try:
        resp = await client.get(f"{XON_API}/breach-analytics", params={"email": email})
        resp.raise_for_status() if resp.status_code != 404 else None
    except httpx.HTTPError as exc:
        record_call("xon", healthy=False, latency_ms=(time.monotonic() - started) * 1000,
                    detail=type(exc).__name__)
        raise
    record_call("xon", healthy=True, latency_ms=(time.monotonic() - started) * 1000)
    if resp.status_code == 404:
        return [], "xposedornot"
    details = ((resp.json().get("ExposedBreaches") or {}).get("breaches_details")) or []
    return [
        {
            "name": d.get("breach"),
            "domain": normalize_domain(d.get("domain")),
            "date": d.get("xposed_date") if len(str(d.get("xposed_date") or "")) >= 10 else None,
            "data": [x.strip() for x in (d.get("xposed_data") or "").split(";") if x.strip()],
            "records": d.get("xposed_records"),
            "source": "xposedornot",
        }
        for d in details
        if d.get("breach")
    ], "xposedornot"


async def email_pastes(client: httpx.AsyncClient, email: str) -> list[dict]:
    """Public paste dumps (Pastebin and similar) containing this email."""
    if settings.hibp_mode.lower() == "mock" or settings.xon_mode.lower() == "mock":
        record_call("xon", healthy=True, detail="Deterministic demo fixture")
        return ([{"source": "Demo paste fixture", "id": "demo-1", "title": "Example forum dump (DEMO DATA)",
                  "date": "2024-01-15", "emails": 1}] if email.strip().lower() == MOCK_EMAIL else [])
    if settings.hibp_api_key:
        resp = await _hibp_keyed_get(client, f"/pasteaccount/{quote(email)}")
        if resp.status_code == 404:
            return []
        resp.raise_for_status()
        return [
            {"source": p.get("Source"), "id": p.get("Id"), "title": p.get("Title"), "date": p.get("Date"), "emails": p.get("EmailCount")}
            for p in resp.json()
        ]

    resp = await client.get(f"{XON_API}/breach-analytics", params={"email": email})
    if resp.status_code == 404:
        return []
    resp.raise_for_status()
    summary = resp.json().get("PastesSummary") or {}
    count = int(summary.get("cnt") or 0)
    if not count:
        return []
    return [{"source": "Public pastes", "id": None, "title": f"{count} paste(s)", "date": summary.get("tmpstmp"), "emails": None}]


def _merge(breaches: list[dict]) -> list[dict]:
    """One entry per breach; an email-confirmed hit outranks a service-level one."""
    merged: dict[str, dict] = {}
    for b in breaches:
        key = (b["name"] or "").lower()
        if key not in merged or b["source"] in ACCOUNT_SOURCES:
            merged[key] = b
    return list(merged.values())


async def _persist(account: Account, breaches: list[dict], db: AsyncSession) -> None:
    for b in breaches:
        existing = await db.execute(
            select(BreachRecord).where(BreachRecord.account_id == account.id, BreachRecord.breach_name == b["name"])
        )
        if existing.scalar_one_or_none():
            continue
        confirmed = b["source"] in ACCOUNT_SOURCES
        db.add(BreachRecord(
            account_id=account.id,
            breach_name=b["name"],
            breach_date=_parse_date(b.get("date")),
            data_exposed=b.get("data", []),
            source=b["source"],
        ))
        exposed = ", ".join(b.get("data", [])) or "unspecified data"
        db.add(Notification(
            user_id=account.user_id,
            title=f"{'Your account was in' if confirmed else 'Service breached'}: {b['name']}",
            message=(
                f"{account.email_used} appears in the {b['name']} breach. Exposed: {exposed}."
                if confirmed
                else f"{account.service_name} was breached ({b.get('date') or 'date unknown'}). "
                f"If your account existed then, change its password. Exposed: {exposed}."
            ),
            severity="critical" if confirmed else "warning",
            related_account_id=account.id,
        ))
        if confirmed:
            from app.services.family import notify_guardians_of_breach  # avoid an import cycle at load time
            await notify_guardians_of_breach(account.user_id, b["name"], db)

    account.breach_count = len(breaches)
    dates = [d for d in (_parse_date(b.get("date")) for b in breaches) if d]
    account.last_breach_date = max(dates) if dates else None


async def _scan(accounts: list[Account], db: AsyncSession) -> dict:
    errors: list[str] = []
    email_source = None
    by_email: dict[str, list[dict]] = {}

    async with http_client() as client:
        try:
            catalog = await get_breach_catalog(client)
        except httpx.HTTPError as e:
            catalog = []
            errors.append(f"HIBP breach catalog unreachable ({e.__class__.__name__})")

        for email in sorted({a.email_used.strip().lower() for a in accounts if a.email_used}):
            try:
                by_email[email], email_source = await email_breaches(client, email)
            except httpx.HTTPError as e:
                errors.append(f"Email lookup failed for {email} ({e.__class__.__name__})")

    matched: set[tuple[str, str]] = set()
    per_account: list[tuple[Account, list[dict]]] = []
    for account in accounts:
        found = service_breaches(catalog, account)
        email = (account.email_used or "").strip().lower()
        domain = normalize_domain(account.service_url)
        name = (account.service_name or "").strip().lower()
        for b in by_email.get(email, []):
            if _domain_matches(domain, b["domain"]) or (name and name == (b["name"] or "").lower()):
                found.append(b)
                matched.add((email, b["name"]))
        per_account.append((account, _merge(found)))

    for account, breaches in per_account:
        await _persist(account, breaches, db)

    unlisted = []
    for email, breaches in by_email.items():
        owner = next((a for a in accounts if (a.email_used or "").strip().lower() == email), None)
        for b in breaches:
            if (email, b["name"]) in matched:
                continue
            unlisted.append({**b, "email": email})
            if owner:
                db.add(Notification(
                    user_id=owner.user_id,
                    title=f"Found in a breach you haven't listed: {b['name']}",
                    message=f"{email} appears in the {b['name']} breach ({b.get('domain') or 'unknown domain'}), "
                    f"but that service isn't in your inventory. Add it and change its password.",
                    severity="critical",
                ))

    await db.commit()
    for user_id in {a.user_id for a in accounts}:
        await refresh_user_graph(user_id, db)

    return {
        "total_accounts_scanned": len(accounts),
        "affected_accounts": sum(1 for _, b in per_account if b),
        "total_breaches_found": sum(len(b) for _, b in per_account),
        "confirmed_account_breaches": sum(1 for _, bs in per_account for b in bs if b["source"] in ACCOUNT_SOURCES),
        "unlisted_exposures": unlisted,
        "sources": {"catalog": "hibp" if catalog else None, "email": email_source},
        "errors": errors,
    }


async def check_account_breaches(account: Account, db: AsyncSession) -> list[dict]:
    await _scan([account], db)
    result = await db.execute(select(BreachRecord).where(BreachRecord.account_id == account.id))
    return [
        {
            "name": r.breach_name,
            "date": r.breach_date.date().isoformat() if r.breach_date else None,
            "data": r.data_exposed,
            "source": r.source,
        }
        for r in result.scalars().all()
    ]


async def scan_all_accounts(user_id: int, db: AsyncSession) -> dict:
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    return await _scan(list(result.scalars().all()), db)
