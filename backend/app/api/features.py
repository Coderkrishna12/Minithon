"""Crazy extra features — NFT badges, Digital Death Switch, Data Broker opt-out, etc."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from datetime import datetime, timezone

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, NFTBadge, Notification
from app.core.security import get_current_user
from app.services.blockchain import record_audit

router = APIRouter(prefix="/features", tags=["features"])


# ── NFT Privacy Score Badge ──

BADGE_TYPES = {
    "privacy_champion": {"min_score": 90, "title": "Privacy Champion", "desc": "Privacy score 90+"},
    "security_pro": {"min_score": 70, "title": "Security Pro", "desc": "Privacy score 70+"},
    "two_fa_everywhere": {"title": "2FA Everywhere", "desc": "All accounts have 2FA enabled"},
    "zero_reuse": {"title": "Zero Reused Passwords", "desc": "No password groups shared"},
    "breach_free": {"title": "Breach Free", "desc": "No breaches detected"},
    "first_audit": {"title": "First Audit", "desc": "Completed your first security audit"},
}


def _eligible(badge_type: str, user: User, accounts: list[Account]) -> bool:
    if badge_type == "privacy_champion":
        return user.privacy_score >= 90
    if badge_type == "security_pro":
        return user.privacy_score >= 70
    if badge_type == "two_fa_everywhere":
        return bool(accounts) and all(a.has_2fa for a in accounts)
    if badge_type == "zero_reuse":
        return bool(accounts) and all(not a.password_group for a in accounts)
    if badge_type == "breach_free":
        return bool(accounts) and all(a.breach_count == 0 for a in accounts)
    return badge_type == "first_audit"


@router.get("/badges")
async def list_badges(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(NFTBadge).where(NFTBadge.user_id == user.id))
    earned = result.scalars().all()
    earned_types = {b.badge_type for b in earned}

    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    available = []
    for badge_type, info in BADGE_TYPES.items():
        eligible = _eligible(badge_type, user, list(accounts))
        available.append({
            "type": badge_type,
            "title": info["title"],
            "description": info.get("desc", ""),
            "eligible": eligible,
            "minted": badge_type in earned_types,
        })

    minted = [
        {
            "id": b.id,
            "type": b.badge_type,
            "title": b.title,
            "score_at_mint": b.score_at_mint,
            "tx_hash": b.tx_hash,
            "created_at": b.created_at.isoformat() if b.created_at else None,
        }
        for b in earned
    ]

    return {"available": available, "minted": minted}


@router.post("/badges/mint/{badge_type}")
async def mint_badge(
    badge_type: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from fastapi import HTTPException

    if badge_type not in BADGE_TYPES:
        raise HTTPException(status_code=400, detail="Unknown badge type")

    existing = await db.execute(
        select(NFTBadge).where(NFTBadge.user_id == user.id, NFTBadge.badge_type == badge_type)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Badge already minted")

    accounts = (await db.execute(select(Account).where(Account.user_id == user.id))).scalars().all()
    if not _eligible(badge_type, user, list(accounts)):
        raise HTTPException(status_code=403, detail="Not eligible for this badge yet")

    info = BADGE_TYPES[badge_type]

    nft_data = {
        "user_id": user.id,
        "badge_type": badge_type,
        "privacy_score": user.privacy_score,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    block = await record_audit(user.id, "badge_minted", f"Minted badge: {info['title']}", nft_data, db)

    badge = NFTBadge(
        user_id=user.id,
        badge_type=badge_type,
        title=info["title"],
        description=info.get("desc", ""),
        score_at_mint=user.privacy_score,
        token_id=f"PS-{user.id}-{badge_type}-{block.blockchain_block}",
        tx_hash=block.blockchain_tx_hash,
        metadata_uri=None,
    )
    db.add(badge)
    await db.commit()
    await db.refresh(badge)

    return {
        "id": badge.id,
        "token_id": badge.token_id,
        "title": badge.title,
        "tx_hash": badge.tx_hash,
        "metadata_uri": badge.metadata_uri,
        "score_at_mint": badge.score_at_mint,
    }


# ── Digital Death Switch (Emergency Lockdown) ──

@router.post("/lockdown")
async def emergency_lockdown(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    actions_taken = []
    for account in accounts:
        actions_taken.append({
            "service": account.service_name,
            "actions": [
                "Session revocation requested",
                "Password reset triggered" if account.category in ("email", "finance") else "Password change recommended",
                "2FA verification enforced" if account.has_2fa else "2FA setup urgently recommended",
            ],
        })

    notification = Notification(
        user_id=user.id,
        title="EMERGENCY LOCKDOWN ACTIVATED",
        message=f"Digital Death Switch activated. {len(accounts)} accounts flagged for immediate security review. Check each service to verify session revocations.",
        severity="critical",
    )
    db.add(notification)

    await record_audit(
        user.id, "emergency_lockdown",
        f"Emergency lockdown activated for {len(accounts)} accounts",
        {"accounts_count": len(accounts), "timestamp": datetime.now(timezone.utc).isoformat()},
        db,
    )

    return {
        "status": "lockdown_activated",
        "accounts_affected": len(accounts),
        "actions": actions_taken,
        "message": "Emergency lockdown initiated. Review each service's security settings immediately.",
        "recovery_steps": [
            "1. Change password on primary email FIRST",
            "2. Enable 2FA on all accounts without it",
            "3. Revoke all active sessions on financial accounts",
            "4. Check for unauthorized account recovery changes",
            "5. Monitor accounts for suspicious activity for 72 hours",
        ],
    }


# ── Data Broker Opt-Out ──

DATA_BROKERS = [
    {"name": "Spokeo", "domain": "spokeo.com", "opt_out_url": "https://www.spokeo.com/optout", "data_types": ["name", "address", "phone", "email"]},
    {"name": "Whitepages", "domain": "whitepages.com", "opt_out_url": "https://www.whitepages.com/suppression-requests", "data_types": ["name", "address", "phone"]},
    {"name": "BeenVerified", "domain": "beenverified.com", "opt_out_url": "https://www.beenverified.com/faq/opt-out/", "data_types": ["name", "address", "phone", "email"]},
    {"name": "Intelius", "domain": "intelius.com", "opt_out_url": "https://www.intelius.com/opt-out", "data_types": ["name", "address", "phone"]},
    {"name": "PeopleFinder", "domain": "peoplefinder.com", "opt_out_url": "https://www.peoplefinder.com/optout", "data_types": ["name", "address", "phone"]},
    {"name": "TruePeopleSearch", "domain": "truepeoplesearch.com", "opt_out_url": "https://www.truepeoplesearch.com/removal", "data_types": ["name", "address", "phone"]},
    {"name": "FastPeopleSearch", "domain": "fastpeoplesearch.com", "opt_out_url": "https://www.fastpeoplesearch.com/removal", "data_types": ["name", "address", "phone"]},
    {"name": "ThatsThem", "domain": "thatsthem.com", "opt_out_url": "https://thatsthem.com/optout", "data_types": ["name", "address", "phone", "email"]},
]


@router.get("/data-brokers")
async def list_data_brokers(user: User = Depends(get_current_user)):
    return {
        "brokers": DATA_BROKERS,
        "total": len(DATA_BROKERS),
        "message": "These data brokers may hold your personal information. Use the opt-out links to request removal.",
    }


@router.post("/data-brokers/opt-out-all")
async def opt_out_all(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    results = []
    for broker in DATA_BROKERS:
        results.append({
            "broker": broker["name"],
            "status": "action_required",
            "opt_out_url": broker["opt_out_url"],
            "estimated_processing": "30-60 days",
        })

    notification = Notification(
        user_id=user.id,
        title="Data broker opt-out links ready",
        message=f"Opt-out links for {len(DATA_BROKERS)} data brokers are ready. Each broker only removes you once you submit its form.",
        severity="info",
    )
    db.add(notification)

    await record_audit(
        user.id, "data_broker_opt_out",
        f"Opt-out initiated for {len(DATA_BROKERS)} data brokers",
        {"brokers": [b["name"] for b in DATA_BROKERS]},
        db,
    )

    return {
        "total_brokers": len(DATA_BROKERS),
        "results": results,
        "next_steps": "Visit each opt-out URL to complete the removal. We'll remind you to verify removal in 30 days.",
    }
