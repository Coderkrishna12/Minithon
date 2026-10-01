import re

import httpx
from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account
from app.core.security import get_current_user
from app.services.breach_checker import get_breach_catalog, http_client, normalize_domain
from app.services.connections import refresh_user_graph

router = APIRouter(prefix="/import", tags=["import"])

DOMAIN_PATTERN = re.compile(r"(?:@|https?://(?:www\.)?)([a-z0-9-]+(?:\.[a-z0-9-]+)+)", re.IGNORECASE)
MAIL_INFRA = ("sendgrid", "mailchimp", "mandrillapp", "amazonses", "mailgun", "sparkpost", "list-manage", "mcsv", "rsgsv")


def _site_domain(host: str) -> str:
    """Collapse mail.x.com / accounts.x.com to x.com (keeps two-label country suffixes like x.co.uk)."""
    parts = host.lower().strip(".").split(".")
    if len(parts) >= 3 and len(parts[-1]) == 2 and parts[-2] in {"co", "com", "org", "net", "ac", "gov"}:
        return ".".join(parts[-3:])
    return ".".join(parts[-2:])


async def _catalog_by_domain() -> dict[str, dict]:
    async with http_client() as client:
        catalog = await get_breach_catalog(client)
    by_domain: dict[str, dict] = {}
    for b in catalog:
        d = (b.get("Domain") or "").lower()
        if d and (d not in by_domain or (b.get("PwnCount") or 0) > (by_domain[d].get("PwnCount") or 0)):
            by_domain[d] = b
    return by_domain


async def _tracked_names(user_id: int, db: AsyncSession) -> set[str]:
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    names = set()
    for a in result.scalars().all():
        names.add((a.service_name or "").lower())
        if a.service_url:
            names.add(_site_domain(normalize_domain(a.service_url)))
    return names


class EmailImportRequest(BaseModel):
    email_content: str


class BulkImportRequest(BaseModel):
    services: list[str]
    email: str | None = None
    added_via: str = "manual_review"
    import_confidence: float | None = None
    evidence_source: str = "user_confirmed_import_candidate"


class PasswordCsvService(BaseModel):
    model_config = ConfigDict(extra="forbid")
    service_name: str
    password_group: str | None = None


class PasswordCsvImportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    services: list[PasswordCsvService]


@router.post("/fixture-mailbox/scan")
async def scan_fixture_mailbox(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Opt-in local demo fixture representing signup/security receipts; no mailbox is accessed."""
    tracked = await _tracked_names(user.id, db)
    signals = [
        {"service_name": "GitHub", "service_url": "github.com", "confidence": 0.96,
         "source": "DEMO DATA · security alert", "reason": "Account security notification"},
        {"service_name": "Dropbox", "service_url": "dropbox.com", "confidence": 0.91,
         "source": "DEMO DATA · signup receipt", "reason": "Account creation receipt"},
        {"service_name": "Example Newsletter", "service_url": "newsletter.example.invalid", "confidence": 0.18,
         "source": "DEMO DATA · newsletter", "reason": "Newsletter only; not treated as an account"},
    ]
    for item in signals:
        item["already_tracked"] = item["service_name"].lower() in tracked or item["service_url"] in tracked
        item["importable"] = item["confidence"] >= 0.75 and not item["already_tracked"]
    return {
        "mode": "fixture",
        "label": "DEMO DATA — no real mailbox connected",
        "message": "Only account signup/security signals are candidates. Newsletter-only domains are excluded.",
        "discovered": signals,
    }


@router.post("/password-manager-csv")
async def import_password_manager_csv(
    data: PasswordCsvImportRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Accept only client-derived account names and reuse labels; plaintext is rejected by schema."""
    tracked = await _tracked_names(user.id, db)
    added, skipped = [], []
    for row in data.services:
        name = row.service_name.strip()[:200]
        if not name or name.lower() in tracked:
            skipped.append(name)
            continue
        account = Account(
            user_id=user.id, service_name=name, service_url=None, email_used=None,
            category=None, has_2fa=None, login_method="unknown", twofa_method=None,
            password_group=(row.password_group[:100] if row.password_group else None),
            permissions=[], added_via="local_password_manager_csv",
            import_confidence=1.0, evidence_source="password_manager_csv_processed_on_device",
        )
        db.add(account)
        await db.flush()
        tracked.add(name.lower())
        added.append({"id": account.id, "service_name": name, "password_group": account.password_group})
    await db.commit()
    await refresh_user_graph(user.id, db)
    return {
        "added": added, "skipped": skipped,
        "plaintext_received": False,
        "message": "Only service names and locally generated reuse-group labels were accepted.",
    }


@router.post("/scan-email")
async def scan_email_for_accounts(
    data: EmailImportRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    domains = {_site_domain(m) for m in DOMAIN_PATTERN.findall(data.email_content)}
    domains = {d for d in domains if not any(k in d for k in MAIL_INFRA)}
    try:
        catalog = await _catalog_by_domain()
    except httpx.HTTPError:
        catalog = {}
    tracked = await _tracked_names(user.id, db)

    discovered = []
    for domain in sorted(domains):
        breach = catalog.get(domain)
        name = (breach.get("Title") if breach else None) or domain
        discovered.append({
            "service_name": name,
            "category": "other",
            "service_url": domain,
            "permissions": [],
            "breached": bool(breach),
            "breach_name": breach.get("Title") if breach else None,
            "already_tracked": domain in tracked or name.lower() in tracked,
        })

    return {
        "discovered": discovered,
        "new_accounts": sum(1 for d in discovered if not d["already_tracked"]),
        "already_tracked": sum(1 for d in discovered if d["already_tracked"]),
        "catalog_available": bool(catalog),
    }


@router.post("/bulk-add")
async def bulk_add_accounts(
    data: BulkImportRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        catalog = await _catalog_by_domain()
    except httpx.HTTPError:
        catalog = {}
    by_name = {(b.get("Title") or "").lower(): (d, b) for d, b in catalog.items()}
    tracked = await _tracked_names(user.id, db)

    added = []
    skipped = []
    for service_key in data.services:
        key = service_key.strip().lower()
        if key in by_name:
            domain, breach = by_name[key]
        elif "." in key:
            domain, breach = _site_domain(normalize_domain(key)), catalog.get(_site_domain(normalize_domain(key)))
        else:
            domain, breach = "", None
        name = (breach.get("Title") if breach else None) or service_key.strip()

        if name.lower() in tracked or (domain and domain in tracked):
            skipped.append(service_key)
            continue

        account = Account(
            user_id=user.id,
            service_name=name,
            service_url=domain,
            email_used=(data.email if data.added_via == "fixture_mailbox" else (data.email or user.email)),
            category=None,
            permissions=[],
            login_method="unknown",
            has_2fa=None,
            added_via=data.added_via,
            import_confidence=data.import_confidence,
            evidence_source=data.evidence_source,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)
        tracked.update({name.lower(), domain})
        added.append(account)

    await refresh_user_graph(user.id, db)
    return {
        "added": [
            {"id": a.id, "service_name": a.service_name, "category": a.category, "risk_score": a.risk_score}
            for a in added
        ],
        "skipped": skipped,
    }


@router.get("/suggestions")
async def get_import_suggestions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """The largest real breaches for services the user hasn't added yet."""
    try:
        catalog = await _catalog_by_domain()
    except httpx.HTTPError:
        return []
    tracked = await _tracked_names(user.id, db)
    ranked = sorted(catalog.items(), key=lambda kv: kv[1].get("PwnCount") or 0, reverse=True)
    return [
        {
            "service_name": b.get("Title") or domain,
            "category": "other",
            "service_url": domain,
            "breach_date": b.get("BreachDate"),
            "accounts_exposed": b.get("PwnCount"),
        }
        for domain, b in ranked
        if domain not in tracked and (b.get("Title") or "").lower() not in tracked
    ][:20]
