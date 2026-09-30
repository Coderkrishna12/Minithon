import httpx
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.account import Account, BreachRecord, Notification
from app.core.config import get_settings

settings = get_settings()

KNOWN_BREACHES_DB = {
    "adobe.com": [{"name": "Adobe 2013", "date": "2013-10-04", "data": ["email", "password", "username"]}],
    "linkedin.com": [{"name": "LinkedIn 2012", "date": "2012-06-05", "data": ["email", "password"]}],
    "dropbox.com": [{"name": "Dropbox 2012", "date": "2012-07-01", "data": ["email", "password"]}],
    "yahoo.com": [{"name": "Yahoo 2013", "date": "2013-08-01", "data": ["email", "password", "security_questions", "phone"]}],
    "facebook.com": [{"name": "Facebook 2019", "date": "2019-04-01", "data": ["email", "phone", "name"]}],
    "twitter.com": [{"name": "Twitter 2022", "date": "2022-01-01", "data": ["email", "phone"]}],
    "instagram.com": [{"name": "Instagram 2019", "date": "2019-05-20", "data": ["email", "phone", "password"]}],
    "myspace.com": [{"name": "MySpace 2016", "date": "2016-05-31", "data": ["email", "password", "username"]}],
    "canva.com": [{"name": "Canva 2019", "date": "2019-05-24", "data": ["email", "username", "name"]}],
    "zynga.com": [{"name": "Zynga 2019", "date": "2019-09-01", "data": ["email", "password", "username", "phone"]}],
}


async def check_hibp(email: str) -> list[dict]:
    """Check HaveIBeenPwned API for breaches. Falls back to local DB if no API key."""
    if settings.hibp_api_key:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"https://haveibeenpwned.com/api/v3/breachedaccount/{email}",
                    headers={
                        "hibp-api-key": settings.hibp_api_key,
                        "user-agent": "PrivacyShield-HackathonDemo",
                    },
                    params={"truncateResponse": "false"},
                    timeout=10,
                )
                if resp.status_code == 200:
                    return resp.json()
                return []
        except Exception:
            return []
    return []


async def check_account_breaches(account: Account, db: AsyncSession) -> list[dict]:
    """Check an account for known breaches using email and service URL."""
    found_breaches = []

    if account.email_used:
        hibp_results = await check_hibp(account.email_used)
        for breach in hibp_results:
            found_breaches.append({
                "name": breach.get("Name", "Unknown"),
                "date": breach.get("BreachDate"),
                "data": breach.get("DataClasses", []),
                "source": "hibp",
            })

    service_lower = (account.service_name or "").lower()
    service_url = (account.service_url or "").lower()
    for domain, breaches in KNOWN_BREACHES_DB.items():
        if domain.split(".")[0] in service_lower or domain in service_url:
            for b in breaches:
                found_breaches.append({**b, "source": "known_db"})

    for breach_data in found_breaches:
        existing = await db.execute(
            select(BreachRecord).where(
                BreachRecord.account_id == account.id,
                BreachRecord.breach_name == breach_data["name"],
            )
        )
        if not existing.scalar_one_or_none():
            breach_date = None
            if breach_data.get("date"):
                try:
                    breach_date = datetime.fromisoformat(breach_data["date"]).replace(tzinfo=timezone.utc)
                except (ValueError, TypeError):
                    pass
            record = BreachRecord(
                account_id=account.id,
                breach_name=breach_data["name"],
                breach_date=breach_date,
                data_exposed=breach_data.get("data", []),
                source=breach_data.get("source", "unknown"),
            )
            db.add(record)

            notification = Notification(
                user_id=account.user_id,
                title=f"Breach detected: {breach_data['name']}",
                message=f"Your account {account.service_name} ({account.email_used}) was found in the {breach_data['name']} breach. Data exposed: {', '.join(breach_data.get('data', []))}",
                severity="critical",
                related_account_id=account.id,
            )
            db.add(notification)

    if found_breaches:
        account.breach_count = len(found_breaches)
        if found_breaches[0].get("date"):
            try:
                account.last_breach_date = datetime.fromisoformat(found_breaches[0]["date"]).replace(tzinfo=timezone.utc)
            except (ValueError, TypeError):
                pass
        await db.commit()

    return found_breaches


async def scan_all_accounts(user_id: int, db: AsyncSession) -> dict:
    """Scan all accounts for a user."""
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()

    total_breaches = 0
    affected_accounts = 0

    for account in accounts:
        breaches = await check_account_breaches(account, db)
        if breaches:
            total_breaches += len(breaches)
            affected_accounts += 1

    return {
        "total_accounts_scanned": len(accounts),
        "affected_accounts": affected_accounts,
        "total_breaches_found": total_breaches,
    }
