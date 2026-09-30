from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.account import Account, AccountConnection, BreachRecord
from app.core.config import get_settings

settings = get_settings()


async def get_user_context(user_id: int, db: AsyncSession) -> str:
    """Build context string about user's account network for AI chat."""
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()

    account_ids = [a.id for a in accounts]
    conn_result = await db.execute(
        select(AccountConnection).where(AccountConnection.from_account_id.in_(account_ids))
    )
    connections = conn_result.scalars().all()

    breach_result = await db.execute(
        select(BreachRecord).where(BreachRecord.account_id.in_(account_ids))
    )
    breaches = breach_result.scalars().all()

    context_parts = [f"User has {len(accounts)} digital accounts:\n"]
    for a in accounts:
        parts = [f"- {a.service_name} (category: {a.category or 'unknown'}, risk: {a.risk_score:.0f}/100)"]
        if not a.has_2fa:
            parts.append("  [WARNING: No 2FA]")
        if a.password_group:
            parts.append(f"  [Password group: {a.password_group}]")
        if a.login_method != "password":
            parts.append(f"  [Login: {a.login_method}]")
        if a.permissions:
            parts.append(f"  [Permissions: {', '.join(a.permissions)}]")
        context_parts.append(" ".join(parts))

    if connections:
        context_parts.append(f"\nAccount connections ({len(connections)}):")
        for c in connections:
            from_acc = next((a for a in accounts if a.id == c.from_account_id), None)
            to_acc = next((a for a in accounts if a.id == c.to_account_id), None)
            if from_acc and to_acc:
                context_parts.append(f"- {from_acc.service_name} -> {to_acc.service_name} ({c.connection_type})")

    if breaches:
        context_parts.append(f"\nKnown breaches ({len(breaches)}):")
        for b in breaches:
            acc = next((a for a in accounts if a.id == b.account_id), None)
            name = acc.service_name if acc else "Unknown"
            context_parts.append(f"- {name}: {b.breach_name} (data: {', '.join(b.data_exposed or [])})")

    return "\n".join(context_parts)


SYSTEM_PROMPT = """You are PrivacyBot, the AI security assistant for PrivacyShield — a Digital Footprint & Privacy Risk Auditor.

Your role:
- Analyze the user's digital account network and identify risks
- Explain security concepts in simple terms
- Recommend specific actions to improve their privacy score
- Simulate attack scenarios when asked ("what if X gets hacked?")
- Provide personalized advice based on their actual accounts, not generic tips

Guidelines:
- Be concise and actionable
- Prioritize fixes by risk reduction impact
- Flag single points of failure (accounts connected to many others)
- Warn about password reuse and missing 2FA
- Consider cascading risk (one compromised account can unlock others)
- Never ask for actual passwords or sensitive credentials
"""


async def chat_with_ai(
    user_id: int,
    message: str,
    conversation_history: list[dict],
    db: AsyncSession,
) -> str:
    """Chat with PrivacyBot AI assistant."""
    user_context = await get_user_context(user_id, db)

    if settings.anthropic_api_key:
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
            messages = []
            for msg in conversation_history[-10:]:
                messages.append({"role": msg["role"], "content": msg["content"]})
            messages.append({"role": "user", "content": message})

            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1024,
                system=f"{SYSTEM_PROMPT}\n\nCurrent user's digital footprint:\n{user_context}",
                messages=messages,
            )
            return response.content[0].text
        except Exception as e:
            return f"AI service error: {str(e)}. Please check your API key configuration."

    return _local_ai_response(message, user_context)


def _local_ai_response(message: str, context: str) -> str:
    """Fallback local response when no API key is configured."""
    msg_lower = message.lower()

    if "what if" in msg_lower and ("hack" in msg_lower or "compromis" in msg_lower or "breach" in msg_lower):
        return (
            "**Attack Scenario Analysis**\n\n"
            "Based on your account graph, here's what could happen:\n\n"
            "1. If your primary email is compromised, an attacker could use password reset flows to access connected accounts\n"
            "2. Any accounts using the same password group would be immediately vulnerable\n"
            "3. SSO-connected accounts can be accessed without needing separate credentials\n\n"
            "**Recommendation:** Use the Attack Simulator on the Risk Graph page to visualize this chain for any specific account.\n\n"
            "**Priority fixes:**\n"
            "- Enable 2FA on your primary email immediately\n"
            "- Change passwords in shared password groups\n"
            "- Review SSO connections and revoke unnecessary ones"
        )

    if "score" in msg_lower or "risk" in msg_lower or "how am i" in msg_lower:
        return (
            "**Your Privacy Assessment**\n\n"
            "Your privacy score is calculated from:\n"
            "- **Breach history** (30%): Past data breaches affecting your accounts\n"
            "- **Permission scope** (20%): How many sensitive permissions your apps have\n"
            "- **Password reuse** (20%): Accounts sharing the same password\n"
            "- **2FA coverage** (15%): Accounts without two-factor authentication\n"
            "- **Cascading impact** (15%): How connected each account is to others\n\n"
            "Check your Dashboard for the full breakdown and prioritized fix list."
        )

    if "2fa" in msg_lower or "two factor" in msg_lower or "two-factor" in msg_lower:
        return (
            "**Two-Factor Authentication Guide**\n\n"
            "2FA adds a second verification step beyond your password. Here's the priority:\n\n"
            "1. **Email accounts** (highest priority) — they control password resets for everything else\n"
            "2. **Financial accounts** — banking, crypto, payment services\n"
            "3. **Cloud storage** — Google Drive, Dropbox, iCloud\n"
            "4. **Social media** — prevents impersonation and social engineering\n\n"
            "**Best options (in order):**\n"
            "- Hardware key (YubiKey) — most secure\n"
            "- Authenticator app (Google Authenticator, Authy) — very good\n"
            "- SMS codes — better than nothing, but vulnerable to SIM swaps\n\n"
            "Check your accounts list — any showing 'No 2FA' should be addressed."
        )

    if "password" in msg_lower:
        return (
            "**Password Security Best Practices**\n\n"
            "Your password groups show which accounts share credentials. Each group is a single point of failure.\n\n"
            "**Action items:**\n"
            "1. Use a password manager (Bitwarden, 1Password) to generate unique passwords\n"
            "2. Start with your highest-risk accounts (email, finance)\n"
            "3. Make each password 16+ characters with mixed types\n"
            "4. Never reuse passwords across services\n\n"
            "On your Accounts page, accounts with the same password group label share a password. "
            "Change them one at a time, starting with the highest risk score."
        )

    if "permission" in msg_lower or "app" in msg_lower and "access" in msg_lower:
        return (
            "**App Permissions Review**\n\n"
            "Apps often request more permissions than they need. Key red flags:\n\n"
            "- **Calculator/flashlight with camera access** — definitely suspicious\n"
            "- **Social media with contacts + location + microphone** — common but excessive\n"
            "- **Games with SMS or call permissions** — unnecessary\n\n"
            "**Rule of thumb:** If an app doesn't need a permission for its core function, revoke it.\n\n"
            "Check your Accounts page — accounts with 3+ sensitive permissions are flagged for review."
        )

    return (
        "**PrivacyBot**\n\n"
        "I can help you with:\n\n"
        "- **\"What's my risk?\"** — Analyze your current privacy posture\n"
        "- **\"What if Gmail gets hacked?\"** — Simulate attack scenarios\n"
        "- **\"How do I set up 2FA?\"** — Security guides\n"
        "- **\"Which passwords should I change?\"** — Prioritized recommendations\n"
        "- **\"Review my app permissions\"** — Permission analysis\n\n"
        "Ask me anything about your digital security!\n\n"
        "*Note: For full AI responses, configure your Anthropic API key in the .env file.*"
    )


async def analyze_privacy_policy(url: str) -> dict:
    """Analyze a service's privacy policy using NLP with keyword fallback."""
    risk_flags = {
        "data_selling": {"found": False, "keywords": ["sell your data", "share with third parties", "advertising partners", "monetize", "third-party advertisers"]},
        "indefinite_retention": {"found": False, "keywords": ["indefinitely", "as long as necessary", "no defined period", "retain indefinitely", "perpetual"]},
        "cross_border": {"found": False, "keywords": ["transfer to other countries", "international transfer", "outside your jurisdiction", "cross-border"]},
        "government_disclosure": {"found": False, "keywords": ["law enforcement", "government request", "legal obligation", "court order", "subpoena"]},
        "biometric_data": {"found": False, "keywords": ["biometric", "facial recognition", "fingerprint", "voiceprint", "face scan"]},
        "location_tracking": {"found": False, "keywords": ["precise location", "GPS", "location history", "geolocation", "real-time location"]},
        "data_sharing_partners": {"found": False, "keywords": ["analytics partners", "business partners", "affiliates", "subsidiaries"]},
        "behavioral_tracking": {"found": False, "keywords": ["behavioral", "tracking pixels", "cookies", "device fingerprint", "browsing history"]},
    }

    policy_text = ""
    try:
        import httpx
        async with httpx.AsyncClient(follow_redirects=True, timeout=10) as client:
            resp = await client.get(url, headers={"User-Agent": "PrivacyShield-Analyzer/1.0"})
            if resp.status_code == 200:
                import re
                html = resp.text[:100000]
                policy_text = re.sub(r'<[^>]+>', ' ', html)
                policy_text = re.sub(r'\s+', ' ', policy_text).strip()[:50000]
    except Exception:
        pass

    if policy_text:
        text_lower = policy_text.lower()
        for flag_data in risk_flags.values():
            for keyword in flag_data["keywords"]:
                if keyword.lower() in text_lower:
                    flag_data["found"] = True
                    break

    flags_found = sum(1 for v in risk_flags.values() if v["found"])
    risk_score = min(flags_found * 13, 100)

    if settings.anthropic_api_key and policy_text:
        try:
            import anthropic
            import json
            client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=800,
                system="You are a privacy policy analyst. Analyze the text and return ONLY valid JSON: {\"summary\": string, \"risk_score\": 0-100, \"key_concerns\": [strings], \"recommendation\": string}",
                messages=[{"role": "user", "content": f"Analyze this privacy policy from {url}:\n\n{policy_text[:10000]}"}],
            )
            ai_text = response.content[0].text
            try:
                ai_result = json.loads(ai_text)
                return {
                    "url": url, "status": "analyzed",
                    "summary": ai_result.get("summary", ""),
                    "risk_flags": {k: v["found"] for k, v in risk_flags.items()},
                    "risk_score": ai_result.get("risk_score", risk_score),
                    "key_concerns": ai_result.get("key_concerns", []),
                    "recommendation": ai_result.get("recommendation", ""),
                }
            except json.JSONDecodeError:
                pass
        except Exception:
            pass

    severity = "low" if risk_score < 30 else "moderate" if risk_score < 60 else "high"
    concerns = [k.replace("_", " ").title() for k, v in risk_flags.items() if v["found"]]
    return {
        "url": url,
        "status": "keyword_analysis" if policy_text else "no_content",
        "summary": f"Found {flags_found} risk indicators." if policy_text else "Could not fetch policy content.",
        "risk_flags": {k: v["found"] for k, v in risk_flags.items()},
        "risk_score": risk_score, "severity": severity,
        "key_concerns": concerns,
        "recommendation": f"This policy has {severity} risk. Review: {', '.join(concerns)}." if concerns else "No major red flags detected.",
    }


async def smart_permission_advisor(user_id: int, db: AsyncSession) -> list[dict]:
    """AI-powered permission recommendations for each account."""
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()

    SENSITIVE_PERMS = {"location", "camera", "microphone", "contacts", "storage", "phone", "sms", "health", "biometric"}
    CATEGORY_NEEDED = {
        "social": {"camera", "contacts", "storage"},
        "email": {"contacts", "storage"},
        "finance": {"camera"},
        "cloud": {"storage"},
        "shopping": {"camera", "location"},
        "gaming": set(),
        "work": {"camera", "microphone", "storage", "contacts"},
        "entertainment": set(),
    }

    recommendations = []
    for a in accounts:
        perms = set(a.permissions or [])
        needed = CATEGORY_NEEDED.get(a.category or "other", set())
        unnecessary = perms & SENSITIVE_PERMS - needed
        missing_useful = needed - perms

        if unnecessary or not a.has_2fa or a.password_group:
            advice = []
            if unnecessary:
                advice.append(f"Revoke unnecessary permissions: {', '.join(unnecessary)}")
            if not a.has_2fa:
                advice.append("Enable 2FA for better security")
            if a.password_group:
                advice.append("Use a unique password (currently in a reuse group)")

            risk_reduction = len(unnecessary) * 3 + (10 if not a.has_2fa else 0) + (8 if a.password_group else 0)

            recommendations.append({
                "account_id": a.id,
                "service_name": a.service_name,
                "category": a.category,
                "current_permissions": list(perms),
                "unnecessary_permissions": list(unnecessary),
                "recommended_permissions": list(needed & perms),
                "advice": advice,
                "risk_reduction": min(risk_reduction, 30),
                "priority": "high" if len(unnecessary) >= 3 or not a.has_2fa else "medium",
            })

    if settings.anthropic_api_key and recommendations:
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
            context = "\n".join(
                f"- {r['service_name']} ({r['category']}): permissions={r['current_permissions']}, unnecessary={r['unnecessary_permissions']}"
                for r in recommendations[:10]
            )
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=600,
                system="You are a privacy advisor. Give a brief overall recommendation (2-3 sentences) about the user's app permissions.",
                messages=[{"role": "user", "content": f"Analyze these permissions:\n{context}"}],
            )
            for r in recommendations:
                r["ai_insight"] = response.content[0].text
        except Exception:
            pass

    recommendations.sort(key=lambda r: r["risk_reduction"], reverse=True)
    return recommendations


async def digital_twin_simulation(user_id: int, db: AsyncSession) -> dict:
    """Simulate a red-team attack on the user's digital twin."""
    user_context = await get_user_context(user_id, db)
    result = await db.execute(select(Account).where(Account.user_id == user_id))
    accounts = result.scalars().all()

    if not accounts:
        return {"error": "No accounts to simulate"}

    attack_vectors = []

    no_2fa = [a for a in accounts if not a.has_2fa]
    if no_2fa:
        attack_vectors.append({
            "vector": "Credential Stuffing",
            "targets": [a.service_name for a in no_2fa[:5]],
            "success_probability": min(30 + len(no_2fa) * 8, 90),
            "description": f"{len(no_2fa)} accounts lack 2FA and are vulnerable to credential stuffing attacks using leaked password databases.",
        })

    pw_groups = {}
    for a in accounts:
        if a.password_group:
            pw_groups.setdefault(a.password_group, []).append(a)
    for group, accs in pw_groups.items():
        if len(accs) > 1:
            attack_vectors.append({
                "vector": "Password Reuse Chain",
                "targets": [a.service_name for a in accs],
                "success_probability": min(50 + len(accs) * 10, 95),
                "description": f"Password group '{group}' shared across {len(accs)} accounts. Compromising one gives access to all.",
            })

    email_accs = [a for a in accounts if a.category == "email"]
    if email_accs:
        dependent = [a for a in accounts if a.recovery_email or a.login_method in ("google_sso", "apple_sso")]
        attack_vectors.append({
            "vector": "Email Account Takeover",
            "targets": [a.service_name for a in email_accs],
            "success_probability": 70 if not email_accs[0].has_2fa else 20,
            "description": f"Primary email controls password resets for {len(dependent)} dependent accounts. {'HIGH RISK: No 2FA on email!' if not email_accs[0].has_2fa else 'Mitigated by 2FA.'}",
            "cascade_count": len(dependent),
        })

    social_eng = [a for a in accounts if a.category == "social" and len(a.permissions or []) >= 3]
    if social_eng:
        attack_vectors.append({
            "vector": "Social Engineering via Excessive Permissions",
            "targets": [a.service_name for a in social_eng],
            "success_probability": 40,
            "description": f"{len(social_eng)} social accounts have 3+ sensitive permissions, enabling data harvesting for targeted phishing.",
        })

    finance_accs = [a for a in accounts if a.category == "finance"]
    for fa in finance_accs:
        prob = 15
        if not fa.has_2fa:
            prob += 40
        if fa.password_group:
            prob += 25
        attack_vectors.append({
            "vector": "Financial Account Breach",
            "targets": [fa.service_name],
            "success_probability": min(prob, 95),
            "description": f"Financial account '{fa.service_name}' — {'CRITICAL: No 2FA!' if not fa.has_2fa else '2FA enabled.'} {'Password reused!' if fa.password_group else 'Unique password.'}",
        })

    overall_risk = sum(v["success_probability"] for v in attack_vectors) / max(len(attack_vectors), 1)

    ai_analysis = ""
    if settings.anthropic_api_key:
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=500,
                system="You are a red-team security analyst. Given the user's digital footprint and attack vectors, provide a brief (3-4 sentences) executive summary of their biggest vulnerabilities and top 3 priority actions.",
                messages=[{"role": "user", "content": f"User context:\n{user_context}\n\nAttack vectors found: {len(attack_vectors)}, Overall risk: {overall_risk:.0f}%"}],
            )
            ai_analysis = response.content[0].text
        except Exception:
            pass

    attack_vectors.sort(key=lambda v: v["success_probability"], reverse=True)

    return {
        "overall_risk_score": round(overall_risk),
        "total_attack_vectors": len(attack_vectors),
        "attack_vectors": attack_vectors,
        "ai_analysis": ai_analysis or f"Found {len(attack_vectors)} attack vectors with {overall_risk:.0f}% average success probability. Priority: enable 2FA on all accounts, eliminate password reuse, and review excessive permissions.",
        "recommendations": [
            "Enable 2FA on all accounts, especially email and finance",
            "Use unique passwords for every account (use a password manager)",
            "Revoke unnecessary app permissions",
            "Monitor accounts for suspicious activity",
            "Set up breach monitoring alerts",
        ],
    }


def predict_breach_probability(account: dict) -> dict:
    """Predict breach probability for an account based on historical patterns."""
    base_probability = 0.05
    category_risk = {
        "social": 0.15, "email": 0.10, "cloud": 0.08, "shopping": 0.12,
        "gaming": 0.18, "finance": 0.06, "productivity": 0.07, "other": 0.10,
    }
    cat_risk = category_risk.get(account.get("category", "other"), 0.10)
    breach_history_factor = min(account.get("breach_count", 0) * 0.08, 0.30)
    no_2fa_factor = 0.10 if not account.get("has_2fa") else 0.0
    reuse_factor = 0.12 if account.get("password_group") else 0.0

    probability = min(base_probability + cat_risk + breach_history_factor + no_2fa_factor + reuse_factor, 0.95)

    risk_level = "low"
    if probability >= 0.4:
        risk_level = "critical"
    elif probability >= 0.25:
        risk_level = "high"
    elif probability >= 0.15:
        risk_level = "medium"

    return {
        "service": account.get("service_name", "Unknown"),
        "probability_6_months": round(probability * 100, 1),
        "risk_level": risk_level,
        "factors": {
            "category_risk": round(cat_risk * 100, 1),
            "breach_history": round(breach_history_factor * 100, 1),
            "no_2fa_penalty": round(no_2fa_factor * 100, 1),
            "password_reuse_penalty": round(reuse_factor * 100, 1),
        },
        "recommendation": (
            "Enable 2FA and change password immediately" if risk_level == "critical"
            else "Enable 2FA and consider using a unique password" if risk_level == "high"
            else "Monitor for breaches" if risk_level == "medium"
            else "Good standing"
        ),
    }
