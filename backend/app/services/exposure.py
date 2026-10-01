"""'What a hacker already knows about you': a live exposure profile for any email address.

Pulls the breaches and paste dumps an address appears in, enriches each breach from the
Have I Been Pwned catalogue, and turns the leaked data types into plain-language risks.
Nothing is written to the database: the profile exists only in the response.
"""
from __future__ import annotations

import html
import re
from datetime import datetime, timezone

from app.services import breach_checker
from app.services.breach_checker import email_breaches, email_pastes, get_breach_catalog, normalize_domain

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

# Leaked data types grouped into what they mean for the person.
BUCKETS = [
    ("passwords", "Passwords", ("password", "hash", "security question", "auth token", "pin")),
    ("financial", "Money", ("credit card", "bank", "payment", "financial", "card", "income", "salar", "tax")),
    ("identity", "Identity", ("date of birth", "dates of birth", "government", "passport", "national id",
                              "social security", "aadhaar", "driver", "gender", "full name")),
    ("location", "Location", ("geographic", "location", "ip address", "gps")),
    ("contact", "Phone & home", ("phone", "physical address", "address", "postcode", "zip")),
    ("social", "Online identity", ("username", "social media", "profile", "website", "avatar", "nickname")),
    ("private", "Private life", ("sexual", "religio", "politic", "health", "ethnic", "relationship", "private message",
                                 "chat", "photo", "family")),
]

ATTACKS = {
    "passwords": ("Credential stuffing", "Leaked passwords are fed into bots that try them on Gmail, banks and shops within hours."),
    "financial": ("Financial fraud", "Card or bank details make it possible to spend money or open credit in your name."),
    "identity": ("Identity theft", "Name, birth date and ID details are what's needed to impersonate you, including to your bank."),
    "contact": ("SIM swap and smishing", "With your phone number an attacker can trick your carrier into moving your SIM and catch your OTPs."),
    "location": ("Physical tracking", "Addresses and IP locations reveal where you live and work."),
    "social": ("Targeted phishing", "Usernames and profiles let attackers write messages that look like they come from people you know."),
    "private": ("Blackmail and scams", "Private details are used for extortion and highly convincing scams."),
}


# Whole-word types that substring matching would confuse ("names" vs "usernames").
EXACT = {"names": "identity", "ages": "identity", "genders": "identity", "pan": "identity"}


def _bucket(data_type: str) -> str | None:
    t = data_type.lower().strip()
    if t in ("email addresses", "email address", "emails"):
        return None  # always present; not news to anyone
    if t in EXACT:
        return EXACT[t]
    for key, _, needles in BUCKETS:
        if any(n in t for n in needles):
            return key
    return "social"


def _year(value) -> int | None:
    m = re.search(r"(19|20)\d{2}", str(value or ""))
    return int(m.group(0)) if m else None


def _strip(text: str | None, limit: int = 220) -> str | None:
    if not text:
        return None
    plain = html.unescape(re.sub(r"<[^>]+>", "", text)).strip()
    return plain if len(plain) <= limit else plain[: limit - 1].rsplit(" ", 1)[0] + "…"


async def exposure_profile(email: str) -> dict:
    email = email.strip().lower()
    if not EMAIL_RE.match(email):
        raise ValueError("That doesn't look like an email address.")

    async with breach_checker.http_client() as client:
        breaches, source = await email_breaches(client, email)
        try:
            pastes = await email_pastes(client, email)
        except Exception:
            pastes = []
        try:
            catalog = await get_breach_catalog(client)
        except Exception:
            catalog = []

    by_name = {}
    by_domain = {}
    for c in catalog:
        for key in (c.get("Name"), c.get("Title")):
            if key:
                by_name[key.lower()] = c
        if c.get("Domain"):
            by_domain.setdefault(c["Domain"].lower(), c)

    items = []
    for b in breaches:
        hit = by_name.get((b.get("name") or "").lower()) or by_domain.get(normalize_domain(b.get("domain")))
        data = list(dict.fromkeys([*(b.get("data") or []), *((hit or {}).get("DataClasses") or [])]))
        date = (hit or {}).get("BreachDate") or b.get("date")
        items.append({
            "name": (hit or {}).get("Title") or b.get("name"),
            "domain": b.get("domain") or (hit or {}).get("Domain"),
            "date": date,
            "year": _year(date),
            "records": (hit or {}).get("PwnCount") or b.get("records"),
            "data": data,
            "buckets": sorted({k for k in (_bucket(d) for d in data) if k}),
            "sensitive": bool((hit or {}).get("IsSensitive")),
            "description": _strip((hit or {}).get("Description")),
        })
    items.sort(key=lambda x: (x["year"] or 0, x["name"] or ""), reverse=True)

    exposed: dict[str, dict] = {}
    for key, label, _ in BUCKETS:
        hits = [i for i in items if key in i["buckets"]]
        if hits:
            types = sorted({d for i in hits for d in i["data"] if _bucket(d) == key})
            exposed[key] = {"key": key, "label": label, "types": types, "breaches": len(hits)}

    years = [i["year"] for i in items if i["year"]]
    password_breaches = sum(1 for i in items if "passwords" in i["buckets"])
    level = (
        "critical" if password_breaches >= 2 or "financial" in exposed or len(items) >= 8
        else "high" if password_breaches or len(items) >= 3
        else "medium" if items or pastes
        else "clear"
    )
    worst = max(items, key=lambda i: (len(i["buckets"]), i["records"] or 0), default=None)
    first = min(years) if years else None

    return {
        "email": email,
        "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": source,
        "level": level,
        "summary": {
            "breaches": len(items),
            "pastes": len(pastes),
            "password_breaches": password_breaches,
            "first_year": first,
            "last_year": max(years) if years else None,
            "years_exposed": (datetime.now(timezone.utc).year - first) if first else 0,
            "records_in_breaches": sum(i["records"] or 0 for i in items),
            "data_types": len({d for i in items for d in i["data"]}),
        },
        "exposed": list(exposed.values()),
        "attacks": [{"key": k, "title": ATTACKS[k][0], "detail": ATTACKS[k][1]} for k in exposed if k in ATTACKS],
        "breaches": items,
        "worst": worst,
        "stored": False,
    }
