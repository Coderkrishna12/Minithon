"""
Seed the PrivacyShield database with realistic demo data.
Run:  cd backend && python seed_data.py
"""
import asyncio
import sys
import os
from datetime import datetime, timezone, timedelta

sys.path.insert(0, os.path.dirname(__file__))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.db.session import engine, async_session, init_db
from app.db.base import Base
from app.models.user import User
from app.models.account import (
    Account, AccountConnection, BreachRecord, AuditLog, Notification,
    NFTBadge, ScoreHistory, FamilyGroup, FamilyMember, DIDIdentity,
    DAOProposal, DAOVote, ReviewReminder, DarkWebAlert, FixAction,
)
from app.core.security import hash_password
from app.services.blockchain import record_audit


DEMO_EMAIL = "demo@privacyshield.app"
DEMO_USERNAME = "demo"
DEMO_PASSWORD = "Demo@1234"

NOW = datetime.now(timezone.utc)


async def seed():
    await init_db()
    async with async_session() as db:
        # ── Check if already seeded ──
        from sqlalchemy import select
        existing = await db.execute(select(User).where(User.email == DEMO_EMAIL))
        if existing.scalar_one_or_none():
            print("✅ Demo user already exists. Skipping seed.")
            return

        # ── 1. Create demo user ──
        user = User(
            email=DEMO_EMAIL,
            username=DEMO_USERNAME,
            hashed_password=hash_password(DEMO_PASSWORD),
            full_name="Demo User",
            privacy_score=62,
        )
        db.add(user)
        await db.flush()
        uid = user.id
        print(f"👤 Created user: {DEMO_EMAIL} / {DEMO_PASSWORD}  (id={uid})")

        # ── 2. Create accounts ──
        accounts_data = [
            {"service_name": "Gmail", "service_url": "https://mail.google.com", "email_used": "demo@gmail.com", "category": "email", "has_2fa": True, "login_method": "password", "permissions": ["contacts", "calendar"], "risk_score": 35, "breach_count": 1},
            {"service_name": "Facebook", "service_url": "https://facebook.com", "email_used": "demo@gmail.com", "category": "social", "has_2fa": False, "login_method": "password", "password_group": "reused_group_1", "permissions": ["location", "contacts", "camera", "microphone"], "risk_score": 72, "breach_count": 3},
            {"service_name": "Twitter / X", "service_url": "https://x.com", "email_used": "demo@gmail.com", "category": "social", "has_2fa": True, "login_method": "google_sso", "permissions": ["location"], "risk_score": 28, "breach_count": 0},
            {"service_name": "Amazon", "service_url": "https://amazon.com", "email_used": "demo@gmail.com", "category": "shopping", "has_2fa": False, "login_method": "password", "password_group": "reused_group_1", "permissions": ["location"], "risk_score": 55, "breach_count": 1},
            {"service_name": "GitHub", "service_url": "https://github.com", "email_used": "demo@gmail.com", "category": "cloud", "has_2fa": True, "login_method": "password", "permissions": [], "risk_score": 15, "breach_count": 0},
            {"service_name": "Instagram", "service_url": "https://instagram.com", "email_used": "demo@gmail.com", "category": "social", "has_2fa": False, "login_method": "facebook_sso", "permissions": ["camera", "microphone", "contacts", "location"], "risk_score": 68, "breach_count": 2},
            {"service_name": "PayPal", "service_url": "https://paypal.com", "email_used": "demo@gmail.com", "category": "finance", "has_2fa": True, "login_method": "password", "permissions": [], "risk_score": 22, "breach_count": 0},
            {"service_name": "Netflix", "service_url": "https://netflix.com", "email_used": "demo@gmail.com", "category": "entertainment", "has_2fa": False, "login_method": "password", "password_group": "reused_group_2", "permissions": [], "risk_score": 40, "breach_count": 0},
            {"service_name": "Spotify", "service_url": "https://spotify.com", "email_used": "demo@gmail.com", "category": "entertainment", "has_2fa": False, "login_method": "facebook_sso", "permissions": ["microphone"], "risk_score": 38, "breach_count": 0},
            {"service_name": "LinkedIn", "service_url": "https://linkedin.com", "email_used": "demo@gmail.com", "category": "social", "has_2fa": True, "login_method": "password", "permissions": ["contacts"], "risk_score": 45, "breach_count": 2},
            {"service_name": "Dropbox", "service_url": "https://dropbox.com", "email_used": "demo@gmail.com", "category": "cloud", "has_2fa": False, "login_method": "google_sso", "permissions": ["camera"], "risk_score": 50, "breach_count": 1},
            {"service_name": "Uber", "service_url": "https://uber.com", "email_used": "demo@gmail.com", "category": "other", "has_2fa": False, "login_method": "password", "permissions": ["location"], "risk_score": 48, "breach_count": 1},
        ]

        account_objs = []
        for ad in accounts_data:
            a = Account(user_id=uid, recovery_email="demo-recovery@gmail.com", **ad)
            db.add(a)
            account_objs.append(a)
        await db.flush()
        print(f"📋 Created {len(account_objs)} accounts")

        # ── 3. Create account connections ──
        connections = [
            (0, 2, "sso"),            # Gmail → Twitter (Google SSO)
            (0, 10, "sso"),           # Gmail → Dropbox (Google SSO)
            (0, 1, "recovery_email"), # Gmail → Facebook (recovery)
            (0, 3, "recovery_email"), # Gmail → Amazon (recovery)
            (1, 5, "sso"),            # Facebook → Instagram (Facebook SSO)
            (1, 8, "sso"),            # Facebook → Spotify (Facebook SSO)
            (1, 3, "password_reuse"), # Facebook ↔ Amazon (reused password)
            (7, 3, "password_reuse"), # Netflix ↔ Amazon (reused password)
            (4, 9, "data_sharing"),   # GitHub → LinkedIn (data sharing)
        ]
        for fi, ti, ctype in connections:
            db.add(AccountConnection(
                from_account_id=account_objs[fi].id,
                to_account_id=account_objs[ti].id,
                connection_type=ctype,
            ))
        await db.flush()
        print(f"🔗 Created {len(connections)} account connections")

        # ── 4. Create breach records ──
        breaches = [
            (0, "Collection #1", "2019-01-17", ["email", "password"]),
            (1, "Facebook Apr 2021", "2021-04-03", ["email", "phone", "name", "location"]),
            (1, "Facebook Sep 2018", "2018-09-28", ["email", "access_token"]),
            (1, "Onliner Spambot", "2017-08-28", ["email", "password"]),
            (3, "Amazon Ring Breach", "2022-12-15", ["email", "password"]),
            (5, "Instagram 2020", "2020-05-14", ["email", "phone", "bio"]),
            (5, "SocialArks", "2021-01-11", ["email", "phone", "name"]),
            (9, "LinkedIn 2021", "2021-06-22", ["email", "phone", "name", "job_title"]),
            (9, "LinkedIn 2012", "2012-06-05", ["email", "password"]),
            (10, "Dropbox 2012", "2012-07-01", ["email", "password"]),
            (11, "Uber 2016", "2016-10-13", ["email", "phone", "name"]),
        ]
        for ai, bname, bdate, exposed in breaches:
            db.add(BreachRecord(
                account_id=account_objs[ai].id,
                breach_name=bname,
                breach_date=datetime.fromisoformat(bdate + "T00:00:00+00:00"),
                data_exposed=exposed,
                source="hibp",
            ))
        await db.flush()
        print(f"🔓 Created {len(breaches)} breach records")

        # ── 5. Create audit log entries ──
        audit_entries = [
            ("account_added", "Added Gmail to account inventory"),
            ("breach_scan", "Scanned 12 accounts, found 11 breach records"),
            ("privacy_score_update", "Privacy score updated to 62"),
            ("account_added", "Added Facebook to account inventory"),
            ("account_added", "Added GitHub to account inventory"),
            ("connection_detected", "Detected Google SSO connection: Gmail → Twitter"),
            ("password_reuse_detected", "Password reuse detected: Facebook, Amazon"),
        ]
        for action, details in audit_entries:
            log = AuditLog(user_id=uid, action=action, details=details)
            db.add(log)
        await db.flush()
        print(f"📝 Created {len(audit_entries)} audit log entries")

        # ── 6. Create notifications ──
        notifs = [
            ("New breach detected", "Your email demo@gmail.com was found in the 'Collection #1' data breach.", "warning"),
            ("Facebook: 3 breaches found", "Your Facebook account has been exposed in 3 separate data breaches. Enable 2FA immediately.", "critical"),
            ("Password reuse alert", "Facebook and Amazon share the same password. Change one of them now.", "warning"),
            ("Weekly privacy digest", "Your privacy score is 62/100. Enable 2FA on 5 more accounts to improve it.", "info"),
            ("LinkedIn breach update", "New data from the LinkedIn 2021 breach is being traded on dark web forums.", "critical"),
        ]
        for title, msg, sev in notifs:
            db.add(Notification(user_id=uid, title=title, message=msg, severity=sev))
        await db.flush()
        print(f"🔔 Created {len(notifs)} notifications")

        # ── 7. Create score history ──
        for days_ago, score, event in [
            (30, 45, "Initial scan"),
            (25, 48, "Enabled 2FA on Gmail"),
            (20, 52, "Added recovery email"),
            (14, 55, "Enabled 2FA on GitHub"),
            (7, 58, "Enabled 2FA on PayPal"),
            (3, 60, "Enabled 2FA on LinkedIn"),
            (0, 62, "Current score"),
        ]:
            db.add(ScoreHistory(
                user_id=uid,
                privacy_score=score,
                total_accounts=12,
                accounts_at_risk=max(0, 7 - days_ago // 5),
                breaches_total=11,
                event_type="score_update",
                event_description=event,
                created_at=NOW - timedelta(days=days_ago),
            ))
        await db.flush()
        print("📈 Created score history")

        # ── 8. Create DAO proposals ──
        proposals = [
            ("Report: Facebook data selling to advertisers", "Facebook has been sharing user browsing data with third-party advertisers without explicit consent.", "Facebook", "2024-06-15", 24, 3),
            ("Confirm: LinkedIn 2021 breach scope", "The LinkedIn 2021 breach affected 700M users. Scraped data includes emails, phone numbers, and geolocation.", "LinkedIn", "2021-06-22", 18, 1),
            ("Report: TikTok excessive data collection", "TikTok collects clipboard data, device identifiers, and browsing history beyond what is disclosed.", "TikTok", "2024-03-01", 31, 8),
        ]
        for title, desc, svc, bdate, vf, va in proposals:
            db.add(DAOProposal(
                author_id=uid, title=title, description=desc,
                service_name=svc, breach_date=bdate,
                votes_for=vf, votes_against=va, status="active",
            ))
        await db.flush()
        print(f"🗳️  Created {len(proposals)} DAO proposals")

        # ── 9. Create dark web alerts ──
        alerts = [
            ("credential_dump", "DarkLeaks Forum", "Email demo@gmail.com found in credential dump (2024-08)", "critical"),
            ("database_leak", "BreachForums", "Phone number associated with your Facebook account found in leaked database", "warning"),
            ("identity_listing", "Telegram Channel", "Full name + address combination matching your profile listed for sale", "critical"),
        ]
        for atype, source, data, sev in alerts:
            db.add(DarkWebAlert(user_id=uid, alert_type=atype, source=source, data_found=data, severity=sev))
        await db.flush()
        print(f"🕸️  Created {len(alerts)} dark web alerts")

        # ── 10. Create reminders ──
        reminders = [
            ("Review Facebook permissions", "Check and revoke unnecessary app permissions on Facebook", "permissions_review", 30),
            ("Change reused passwords", "Facebook and Amazon share the same password — change one", "password_change", 7),
            ("Check Google privacy settings", "Review Google Dashboard privacy & data settings", "privacy_audit", 90),
            ("Verify 2FA on financial accounts", "Ensure PayPal and banking accounts have 2FA enabled", "security_check", 14),
        ]
        for title, desc, rtype, freq in reminders:
            db.add(ReviewReminder(
                user_id=uid, reminder_type=rtype, title=title,
                description=desc, frequency_days=freq, is_active=True,
                next_trigger=NOW + timedelta(days=freq),
                last_triggered=NOW - timedelta(days=freq),
            ))
        await db.flush()
        print(f"⏰ Created {len(reminders)} reminders")

        # ── 11. Create family group ──
        import secrets as sec
        group = FamilyGroup(
            name="Demo Family", owner_id=uid,
            group_type="family", invite_code=sec.token_hex(4).upper(),
        )
        db.add(group)
        await db.flush()
        db.add(FamilyMember(group_id=group.id, user_id=uid, role="admin"))
        await db.flush()
        print("👨‍👩‍👧‍👦 Created family group")

        # ── 12. Commit everything ──
        await db.commit()
        print("\n✅ Seed complete! All tables populated with demo data.")
        print(f"   Login with:  {DEMO_EMAIL} / {DEMO_PASSWORD}")


if __name__ == "__main__":
    asyncio.run(seed())
