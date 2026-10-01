"""Family Shield: per-member risk snapshots, group insights, and guardian alerts.

Members choose what the group sees. "summary" shares the score and counts only;
"detailed" also names the risky accounts and the services behind shared risks.
A member always sees their own details.
"""
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import DarkWebAlert, FamilyGroup, FamilyMember, FixAction, Notification
from app.models.user import User
from app.services.risk_engine import _load_network, score_network

ROLES = ("owner", "guardian", "member")
SHARE_LEVELS = ("summary", "detailed")
MANAGER_ROLES = ("owner", "guardian")

NUDGE_TOPICS = {
    "enable_2fa": ("Turn on two-factor authentication", "Turn on 2FA for your accounts, starting with email and banking."),
    "change_password": ("Change a breached password", "One of your accounts was in a breach. Change that password and anywhere you reused it."),
    "unique_passwords": ("Stop reusing passwords", "Use a different password for each account. A password manager makes this easy."),
    "run_scan": ("Run a breach scan", "Open PrivacyShield and run a breach scan so the family can see where you stand."),
    "review_fixes": ("Work through your fixes", "You have pending fixes in PrivacyShield. Each one raises your privacy score."),
    "custom": ("A note from your family group", ""),
}


def display_name(user: User) -> str:
    return user.full_name or user.username


def risk_level(score: int) -> str:
    if score < 40:
        return "critical"
    if score < 60:
        return "high"
    if score < 80:
        return "medium"
    return "low"


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


async def member_snapshot(user: User, db: AsyncSession) -> dict:
    """Everything the group view needs about one member, computed live without writing."""
    accounts, connections, breaches = await _load_network(user.id, db)
    scores, components, score = score_network(accounts, connections, breaches)

    breached_ids = {b.account_id for b in breaches}
    reuse = defaultdict(list)
    for a in accounts:
        if a.password_group:
            reuse[a.password_group].append(a.service_name)
    reuse_groups = {g: names for g, names in reuse.items() if len(names) > 1}

    darkweb = (await db.execute(
        select(DarkWebAlert).where(DarkWebAlert.user_id == user.id, DarkWebAlert.is_resolved == False)  # noqa: E712
    )).scalars().all()
    fixes = (await db.execute(select(FixAction).where(FixAction.user_id == user.id))).scalars().all()

    issues = []
    for a in sorted(accounts, key=lambda a: scores[a.id], reverse=True):
        reasons = []
        if a.id in breached_ids:
            reasons.append("in a data breach")
        if a.has_2fa is not True:
            reasons.append("no 2FA")
        if a.password_group in reuse_groups:
            reasons.append("reused password")
        if components[a.id]["keystone"]:
            reasons.append(f"unlocks {components[a.id]['reachable_accounts']} other accounts")
        if reasons:
            issues.append({"service": a.service_name, "risk": round(scores[a.id]), "reasons": reasons})

    return {
        "privacy_score": score,
        "risk_level": risk_level(score),
        "total_accounts": len(accounts),
        "accounts_at_risk": sum(1 for a in accounts if scores[a.id] >= 50),
        "without_2fa": sum(1 for a in accounts if a.has_2fa is not True),
        "email_without_2fa": sum(1 for a in accounts if a.category == "email" and a.has_2fa is not True),
        "breached_accounts": len(breached_ids),
        "reused_password_groups": len(reuse_groups),
        "darkweb_exposures": len(darkweb),
        "pending_fixes": sum(1 for f in fixes if f.status == "pending"),
        "completed_fixes": sum(1 for f in fixes if f.status == "completed"),
        "has_scanned": bool(accounts),
        "top_issues": issues[:5],
        # Kept out of the response; used to find services several members share.
        "_services": {a.service_name.strip().lower(): (a.service_name, a.id in breached_ids) for a in accounts},
        "_recent_breaches": [
            (b.breach_name, _aware(b.created_at)) for b in breaches if b.created_at
        ],
        "_completed": [(f.description or f.action_type, _aware(f.completed_at)) for f in fixes if f.completed_at],
    }


def build_insights(rows: list[dict], viewer_id: int) -> dict:
    """Group-level shared risks, recommendations and activity from member rows.

    Each row has "user", "member" (FamilyMember) and "snap" (member_snapshot).
    """
    def visible(row) -> bool:
        return row["member"].share_level == "detailed" or row["user"].id == viewer_id

    # Services used by two or more members; named only from members sharing details.
    usage = defaultdict(lambda: {"name": "", "members": [], "breached_for": []})
    for row in rows:
        if not visible(row):
            continue
        for key, (name, breached) in row["snap"]["_services"].items():
            entry = usage[key]
            entry["name"] = name
            entry["members"].append(display_name(row["user"]))
            if breached:
                entry["breached_for"].append(display_name(row["user"]))
    shared = sorted(
        (
            {
                "service": e["name"],
                "members": e["members"],
                "breached": bool(e["breached_for"]),
                "advice": (
                    f"{e['name']} has a breach on record. Everyone using it should change that password and turn on 2FA."
                    if e["breached_for"]
                    else f"{len(e['members'])} of you use {e['name']}. Make sure nobody shares a login or password for it."
                ),
            }
            for e in usage.values()
            if len(e["members"]) > 1
        ),
        key=lambda s: (not s["breached"], -len(s["members"])),
    )

    recs = []
    for row in rows:
        snap, name, uid = row["snap"], display_name(row["user"]), row["user"].id
        you = uid == viewer_id
        who = "You" if you else name
        if not snap["has_scanned"]:
            recs.append({"priority": 2, "member_user_id": uid, "topic": "run_scan",
                         "title": f"{who} {'have' if you else 'has'} no accounts tracked yet",
                         "detail": "Add accounts or run a smart import so the group can see real risk."})
            continue
        if snap["email_without_2fa"]:
            recs.append({"priority": 1, "member_user_id": uid, "topic": "enable_2fa",
                         "title": f"Secure {'your' if you else name + chr(39) + 's'} email with 2FA",
                         "detail": "Email resets every other password. Without 2FA it is the easiest way in."})
        if snap["breached_accounts"]:
            recs.append({"priority": 1, "member_user_id": uid, "topic": "change_password",
                         "title": f"{who}: change passwords on {snap['breached_accounts']} breached account(s)",
                         "detail": "Breached passwords are tried automatically on other sites."})
        if snap["reused_password_groups"]:
            recs.append({"priority": 2, "member_user_id": uid, "topic": "unique_passwords",
                         "title": f"{who}: {snap['reused_password_groups']} reused password group(s)",
                         "detail": "One leak opens every account sharing that password."})
        if snap["privacy_score"] < 60 and snap["pending_fixes"]:
            recs.append({"priority": 3, "member_user_id": uid, "topic": "review_fixes",
                         "title": f"{who}: {snap['pending_fixes']} pending fix(es)",
                         "detail": "Completing fixes is the fastest way to raise the family score."})
    for s in shared:
        if s["breached"]:
            recs.append({"priority": 1, "member_user_id": None, "topic": "change_password",
                         "title": f"Shared breached service: {s['service']}",
                         "detail": s["advice"]})
    recs.sort(key=lambda r: r["priority"])

    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    activity = []
    for row in rows:
        name = "You" if row["user"].id == viewer_id else display_name(row["user"])
        detailed = visible(row)
        for breach, when in row["snap"]["_recent_breaches"]:
            if when and when >= cutoff:
                activity.append({"at": when.isoformat(), "kind": "breach",
                                 "text": f"{name} found in the {breach} breach" if detailed else f"{name} found in a new breach"})
        for desc, when in row["snap"]["_completed"]:
            if when and when >= cutoff:
                activity.append({"at": when.isoformat(), "kind": "fix",
                                 "text": f"{name} completed: {desc}" if detailed else f"{name} completed a fix"})
    activity.sort(key=lambda a: a["at"], reverse=True)

    return {"shared_risks": shared, "recommendations": recs[:12], "activity": activity[:20]}


async def notify_guardians_of_breach(user_id: int, breach_name: str, db: AsyncSession) -> None:
    """Tell the owners/guardians of every group this user belongs to about a new breach (no commit)."""
    memberships = (await db.execute(select(FamilyMember).where(FamilyMember.user_id == user_id))).scalars().all()
    if not memberships:
        return
    user = await db.get(User, user_id)
    name = display_name(user) if user else "A member"
    notified: set[int] = set()
    for m in memberships:
        group = await db.get(FamilyGroup, m.group_id)
        managers = (await db.execute(select(FamilyMember).where(
            FamilyMember.group_id == m.group_id,
            FamilyMember.role.in_(MANAGER_ROLES),
            FamilyMember.user_id != user_id,
        ))).scalars().all()
        detail = f"the {breach_name} breach" if m.share_level == "detailed" else "a new data breach"
        for manager in managers:
            if manager.user_id in notified:
                continue
            notified.add(manager.user_id)
            db.add(Notification(
                user_id=manager.user_id,
                title=f"Family Shield: {name} needs help",
                message=f"{name} ({group.name if group else 'your group'}) was found in {detail}. "
                "Open Family Shield to see what to do and send them a nudge.",
                severity="warning",
            ))
