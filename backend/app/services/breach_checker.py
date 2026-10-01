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


from app.services.risk_engine import calculate_account_risk


async def check_hibp(email: str) -> list[dict]:
    """Check HaveIBeenPwned API for breaches."""
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
    """Check an account for verified personal leaks.

    Only genuine email leaks returned by HaveIBeenPwned are treated as confirmed personal breaches.
    Historical service incidents are not falsely attributed to the user's specific credentials.
    """
    found_breaches = []

    # 1. Clean up any obsolete/unverified "known_db" records falsely tied to this account
    obsolete = await db.execute(
        select(BreachRecord).where(
            BreachRecord.account_id == account.id,
            BreachRecord.source == "known_db",
        )
    )
    for rec in obsolete.scalars().all():
        await db.delete(rec)

    # 2. Check HaveIBeenPwned for verified leaks involving this specific email
    if account.email_used:
        hibp_results = await check_hibp(account.email_used)
        for breach in hibp_results:
            found_breaches.append({
                "name": breach.get("Name", "Unknown"),
                "date": breach.get("BreachDate"),
                "data": breach.get("DataClasses", []),
                "source": "hibp",
            })

    # 3. Store verified breaches
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
                source="hibp",
            )
            db.add(record)

            notification = Notification(
                user_id=account.user_id,
                title=f"Verified Breach: {breach_data['name']}",
                message=f"Your email ({account.email_used}) was confirmed in the {breach_data['name']} breach. Exposed data: {', '.join(breach_data.get('data', []))}",
                severity="critical",
                related_account_id=account.id,
            )
            db.add(notification)

    # If no verified breaches, remove false previous notifications
    if not found_breaches:
        false_notifications = await db.execute(
            select(Notification).where(
                Notification.related_account_id == account.id,
                Notification.title.like("%Instagram 2019%"),
            )
        )
        for notif in false_notifications.scalars().all():
            await db.delete(notif)

    # Update account breach metrics strictly reflecting verified leaks
    account.breach_count = len(found_breaches)
    if found_breaches and found_breaches[0].get("date"):
        try:
            account.last_breach_date = datetime.fromisoformat(found_breaches[0]["date"]).replace(tzinfo=timezone.utc)
        except (ValueError, TypeError):
            pass
    else:
        account.last_breach_date = None

    # Recalculate risk score
    account.risk_score = await calculate_account_risk(account, db)

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
