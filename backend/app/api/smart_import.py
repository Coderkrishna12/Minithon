from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account
from app.core.security import get_current_user
from app.services.risk_engine import calculate_account_risk

router = APIRouter(prefix="/import", tags=["import"])

KNOWN_SERVICES = {
    "google": {"category": "email", "url": "google.com", "permissions": ["contacts", "calendar", "drive"]},
    "gmail": {"category": "email", "url": "gmail.com", "permissions": ["contacts", "calendar"]},
    "facebook": {"category": "social", "url": "facebook.com", "permissions": ["contacts", "photos", "location"]},
    "instagram": {"category": "social", "url": "instagram.com", "permissions": ["contacts", "camera", "photos"]},
    "twitter": {"category": "social", "url": "twitter.com", "permissions": ["contacts"]},
    "linkedin": {"category": "work", "url": "linkedin.com", "permissions": ["contacts", "email"]},
    "amazon": {"category": "shopping", "url": "amazon.com", "permissions": ["payment", "address"]},
    "netflix": {"category": "entertainment", "url": "netflix.com", "permissions": []},
    "spotify": {"category": "entertainment", "url": "spotify.com", "permissions": ["contacts"]},
    "github": {"category": "work", "url": "github.com", "permissions": ["repos", "email"]},
    "apple": {"category": "cloud", "url": "apple.com", "permissions": ["contacts", "photos", "location", "health"]},
    "microsoft": {"category": "work", "url": "microsoft.com", "permissions": ["contacts", "calendar", "files"]},
    "dropbox": {"category": "cloud", "url": "dropbox.com", "permissions": ["files"]},
    "paypal": {"category": "finance", "url": "paypal.com", "permissions": ["payment"]},
    "venmo": {"category": "finance", "url": "venmo.com", "permissions": ["contacts", "payment"]},
    "uber": {"category": "other", "url": "uber.com", "permissions": ["location", "contacts", "payment"]},
    "airbnb": {"category": "other", "url": "airbnb.com", "permissions": ["location", "payment"]},
    "discord": {"category": "social", "url": "discord.com", "permissions": ["microphone", "camera"]},
    "twitch": {"category": "gaming", "url": "twitch.com", "permissions": []},
    "steam": {"category": "gaming", "url": "store.steampowered.com", "permissions": []},
    "reddit": {"category": "social", "url": "reddit.com", "permissions": []},
    "tiktok": {"category": "social", "url": "tiktok.com", "permissions": ["camera", "microphone", "contacts", "location"]},
    "snapchat": {"category": "social", "url": "snapchat.com", "permissions": ["camera", "contacts", "location"]},
    "whatsapp": {"category": "social", "url": "whatsapp.com", "permissions": ["contacts", "camera", "microphone", "storage"]},
    "zoom": {"category": "work", "url": "zoom.us", "permissions": ["camera", "microphone", "contacts"]},
    "slack": {"category": "work", "url": "slack.com", "permissions": ["files", "contacts"]},
}


class EmailImportRequest(BaseModel):
    email_content: str


class BulkImportRequest(BaseModel):
    services: list[str]
    email: str


@router.post("/scan-email")
async def scan_email_for_accounts(
    data: EmailImportRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    content_lower = data.email_content.lower()
    discovered = []

    for service_name, info in KNOWN_SERVICES.items():
        if service_name in content_lower or info["url"] in content_lower:
            existing = await db.execute(
                select(Account).where(
                    Account.user_id == user.id,
                    Account.service_name.ilike(f"%{service_name}%"),
                )
            )
            if not existing.scalar_one_or_none():
                discovered.append({
                    "service_name": service_name.title(),
                    "category": info["category"],
                    "service_url": info["url"],
                    "permissions": info["permissions"],
                    "already_tracked": False,
                })
            else:
                discovered.append({
                    "service_name": service_name.title(),
                    "category": info["category"],
                    "already_tracked": True,
                })

    return {
        "discovered": discovered,
        "new_accounts": sum(1 for d in discovered if not d.get("already_tracked")),
        "already_tracked": sum(1 for d in discovered if d.get("already_tracked")),
    }


@router.post("/bulk-add")
async def bulk_add_accounts(
    data: BulkImportRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    added = []
    skipped = []

    for service_key in data.services:
        service_lower = service_key.lower()
        info = KNOWN_SERVICES.get(service_lower, {})

        existing = await db.execute(
            select(Account).where(
                Account.user_id == user.id,
                Account.service_name.ilike(f"%{service_key}%"),
            )
        )
        if existing.scalar_one_or_none():
            skipped.append(service_key)
            continue

        account = Account(
            user_id=user.id,
            service_name=service_key.title(),
            service_url=info.get("url", ""),
            email_used=data.email,
            category=info.get("category", "other"),
            permissions=info.get("permissions", []),
            login_method="password",
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)

        account.risk_score = await calculate_account_risk(account, db)
        await db.commit()

        added.append({
            "id": account.id,
            "service_name": account.service_name,
            "category": account.category,
            "risk_score": account.risk_score,
        })

    return {"added": added, "skipped": skipped}


@router.get("/suggestions")
async def get_import_suggestions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing_result = await db.execute(select(Account).where(Account.user_id == user.id))
    existing = {a.service_name.lower() for a in existing_result.scalars().all()}

    suggestions = []
    for name, info in KNOWN_SERVICES.items():
        if name not in existing and name.title().lower() not in existing:
            suggestions.append({
                "service_name": name.title(),
                "category": info["category"],
                "service_url": info["url"],
            })

    return suggestions
