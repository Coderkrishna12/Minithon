from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, BreachRecord, FixAction, AuditLog, NFTBadge, ScoreHistory
from app.core.security import get_current_user
from app.services.risk_engine import calculate_privacy_score

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/export")
async def export_full_report(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    score = await calculate_privacy_score(user.id, db)

    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    account_ids = [a.id for a in accounts]
    breaches = []
    if account_ids:
        breach_result = await db.execute(
            select(BreachRecord).where(BreachRecord.account_id.in_(account_ids))
        )
        breaches = breach_result.scalars().all()

    fixes_result = await db.execute(select(FixAction).where(FixAction.user_id == user.id))
    fixes = fixes_result.scalars().all()

    badges_result = await db.execute(select(NFTBadge).where(NFTBadge.user_id == user.id))
    badges = badges_result.scalars().all()

    risk_distribution = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    categories = {}
    for a in accounts:
        if a.risk_score >= 75:
            risk_distribution["critical"] += 1
        elif a.risk_score >= 50:
            risk_distribution["high"] += 1
        elif a.risk_score >= 25:
            risk_distribution["medium"] += 1
        else:
            risk_distribution["low"] += 1
        cat = a.category or "other"
        categories[cat] = categories.get(cat, 0) + 1

    no_2fa = [a.service_name for a in accounts if not a.has_2fa]
    pw_groups = {}
    for a in accounts:
        if a.password_group:
            pw_groups.setdefault(a.password_group, []).append(a.service_name)
    reused = {k: v for k, v in pw_groups.items() if len(v) > 1}

    return {
        "report_date": datetime.now(timezone.utc).isoformat(),
        "user": {
            "username": user.username,
            "email": user.email,
            "privacy_score": score,
        },
        "summary": {
            "total_accounts": len(accounts),
            "accounts_at_risk": sum(1 for a in accounts if a.risk_score >= 50),
            "total_breaches": len(breaches),
            "fixes_completed": sum(1 for f in fixes if f.status == "completed"),
            "fixes_pending": sum(1 for f in fixes if f.status == "pending"),
            "badges_earned": len(badges),
        },
        "risk_distribution": risk_distribution,
        "category_breakdown": categories,
        "critical_issues": {
            "accounts_without_2fa": no_2fa,
            "reused_passwords": reused,
        },
        "accounts": [
            {
                "service": a.service_name,
                "category": a.category,
                "risk_score": a.risk_score,
                "has_2fa": a.has_2fa,
                "breach_count": a.breach_count,
                "login_method": a.login_method,
            }
            for a in accounts
        ],
        "breaches": [
            {
                "name": b.breach_name,
                "date": b.breach_date.isoformat() if b.breach_date else None,
                "data_exposed": b.data_exposed,
            }
            for b in breaches
        ],
        "recommendations": [
            {
                "action": f.action_type,
                "description": f.description,
                "priority": f.priority,
                "status": f.status,
            }
            for f in sorted(fixes, key=lambda x: x.priority, reverse=True)
        ],
    }


@router.get("/summary")
async def get_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    score = await calculate_privacy_score(user.id, db)
    accounts_result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = accounts_result.scalars().all()

    strengths = []
    weaknesses = []

    twofa_pct = sum(1 for a in accounts if a.has_2fa) / max(len(accounts), 1) * 100
    if twofa_pct >= 80:
        strengths.append(f"Strong 2FA coverage ({twofa_pct:.0f}%)")
    else:
        weaknesses.append(f"Low 2FA coverage ({twofa_pct:.0f}%) — enable on remaining accounts")

    pw_groups = {}
    for a in accounts:
        if a.password_group:
            pw_groups.setdefault(a.password_group, []).append(a.service_name)
    reused = {k: v for k, v in pw_groups.items() if len(v) > 1}
    if not reused:
        strengths.append("No password reuse detected")
    else:
        weaknesses.append(f"{len(reused)} password groups are reused across {sum(len(v) for v in reused.values())} accounts")

    high_risk = [a for a in accounts if a.risk_score >= 75]
    if not high_risk:
        strengths.append("No critical-risk accounts")
    else:
        weaknesses.append(f"{len(high_risk)} accounts at critical risk level")

    grade = "A" if score >= 90 else "B" if score >= 75 else "C" if score >= 60 else "D" if score >= 40 else "F"

    return {
        "privacy_score": score,
        "grade": grade,
        "total_accounts": len(accounts),
        "strengths": strengths,
        "weaknesses": weaknesses,
        "top_priority": weaknesses[0] if weaknesses else "Keep up the great work!",
    }
