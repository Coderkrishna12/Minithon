import secrets

from fastapi import APIRouter, Depends, HTTPException
from pydantic import AliasChoices, BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.account import FamilyGroup, FamilyMember, Notification
from app.models.user import User
from app.services.family import (
    MANAGER_ROLES, NUDGE_TOPICS, ROLES, SHARE_LEVELS,
    build_insights, display_name, member_snapshot,
)

router = APIRouter(prefix="/family", tags=["family"])

GROUP_TYPES = ("family", "friends", "team", "organization")
# Unambiguous characters only, so codes are easy to read out and type.
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class GroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    # Older clients send "type".
    group_type: str = Field(default="family", validation_alias=AliasChoices("group_type", "type"))


class InviteJoin(BaseModel):
    invite_code: str
    share_level: str = "summary"


class RoleUpdate(BaseModel):
    role: str


class SharingUpdate(BaseModel):
    share_level: str


class Nudge(BaseModel):
    member_user_id: int
    topic: str = "custom"
    message: str | None = Field(default=None, max_length=500)


def _new_code() -> str:
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(8))


def _normalize_code(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch.isalnum())


async def _unique_code(db: AsyncSession) -> str:
    while True:
        code = _new_code()
        if not (await db.execute(select(FamilyGroup).where(FamilyGroup.invite_code == code))).scalar_one_or_none():
            return code


async def _membership(group_id: int, user_id: int, db: AsyncSession) -> tuple[FamilyGroup, FamilyMember]:
    group = await db.get(FamilyGroup, group_id)
    member = (await db.execute(select(FamilyMember).where(
        FamilyMember.group_id == group_id, FamilyMember.user_id == user_id
    ))).scalar_one_or_none()
    if not group or not member:
        raise HTTPException(status_code=404, detail="Group not found")
    return group, member


def _require(member: FamilyMember, roles: tuple[str, ...], action: str) -> None:
    if member.role not in roles:
        raise HTTPException(status_code=403, detail=f"Only the group {' or '.join(roles)} can {action}")


def _group_out(group: FamilyGroup, me: FamilyMember, member_count: int) -> dict:
    return {
        "id": group.id,
        "name": group.name,
        "group_type": group.group_type,
        "member_count": member_count,
        "my_role": me.role,
        "my_share_level": me.share_level,
        "is_owner": me.role == "owner",
        # Owners and guardians can invite; everyone else asks them.
        "invite_code": group.invite_code if me.role in MANAGER_ROLES else None,
    }


@router.post("/groups", status_code=201)
async def create_group(data: GroupCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if data.group_type not in GROUP_TYPES:
        raise HTTPException(status_code=422, detail=f"group_type must be one of {', '.join(GROUP_TYPES)}")
    group = FamilyGroup(name=data.name.strip(), owner_id=user.id, group_type=data.group_type,
                        invite_code=await _unique_code(db))
    db.add(group)
    await db.flush()
    # The owner shares details by default so the group starts with something useful to see.
    me = FamilyMember(group_id=group.id, user_id=user.id, role="owner", share_level="detailed")
    db.add(me)
    await db.commit()
    return _group_out(group, me, 1)


@router.get("/groups")
async def list_groups(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    memberships = (await db.execute(select(FamilyMember).where(FamilyMember.user_id == user.id))).scalars().all()
    out = []
    for me in memberships:
        group = await db.get(FamilyGroup, me.group_id)
        if not group:
            continue
        count = (await db.execute(
            select(func.count(FamilyMember.id)).where(FamilyMember.group_id == group.id)
        )).scalar_one()
        out.append(_group_out(group, me, count))
    return out


@router.post("/join")
async def join_group(data: InviteJoin, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if data.share_level not in SHARE_LEVELS:
        raise HTTPException(status_code=422, detail="share_level must be summary or detailed")
    group = (await db.execute(
        select(FamilyGroup).where(FamilyGroup.invite_code == _normalize_code(data.invite_code))
    )).scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="That invite code doesn't match any group. Check it with the person who sent it.")
    existing = (await db.execute(select(FamilyMember).where(
        FamilyMember.group_id == group.id, FamilyMember.user_id == user.id
    ))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail=f"You're already in {group.name}")

    me = FamilyMember(group_id=group.id, user_id=user.id, role="member", share_level=data.share_level)
    db.add(me)
    managers = (await db.execute(select(FamilyMember).where(
        FamilyMember.group_id == group.id, FamilyMember.role.in_(MANAGER_ROLES)
    ))).scalars().all()
    for m in managers:
        db.add(Notification(user_id=m.user_id, title=f"{display_name(user)} joined {group.name}",
                            message="Open Family Shield to see their privacy snapshot.", severity="info"))
    await db.commit()
    count = (await db.execute(select(func.count(FamilyMember.id)).where(FamilyMember.group_id == group.id))).scalar_one()
    return {"status": "joined", "group_name": group.name, "group": _group_out(group, me, count)}


@router.post("/groups/{group_id}/invite-code")
async def regenerate_invite_code(group_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    group, me = await _membership(group_id, user.id, db)
    _require(me, MANAGER_ROLES, "change the invite code")
    group.invite_code = await _unique_code(db)
    await db.commit()
    return {"invite_code": group.invite_code}


@router.patch("/groups/{group_id}/sharing")
async def update_sharing(group_id: int, data: SharingUpdate, user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)):
    if data.share_level not in SHARE_LEVELS:
        raise HTTPException(status_code=422, detail="share_level must be summary or detailed")
    _, me = await _membership(group_id, user.id, db)
    me.share_level = data.share_level
    await db.commit()
    return {"share_level": me.share_level}


@router.patch("/groups/{group_id}/members/{member_user_id}")
async def update_role(group_id: int, member_user_id: int, data: RoleUpdate,
                      user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if data.role not in ("guardian", "member"):
        raise HTTPException(status_code=422, detail="role must be guardian or member")
    _, me = await _membership(group_id, user.id, db)
    _require(me, ("owner",), "change roles")
    _, target = await _membership(group_id, member_user_id, db)
    if target.role == "owner":
        raise HTTPException(status_code=400, detail="The owner's role can't be changed")
    target.role = data.role
    await db.commit()
    return {"user_id": member_user_id, "role": target.role}


@router.delete("/groups/{group_id}/members/{member_user_id}")
async def remove_member(group_id: int, member_user_id: int, user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    _, me = await _membership(group_id, user.id, db)
    _require(me, ("owner",), "remove members")
    if member_user_id == user.id:
        raise HTTPException(status_code=400, detail="Use leave or delete the group instead")
    _, target = await _membership(group_id, member_user_id, db)
    await db.delete(target)
    await db.commit()
    return {"status": "removed"}


@router.post("/groups/{group_id}/leave")
async def leave_group(group_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    group, me = await _membership(group_id, user.id, db)
    others = (await db.execute(select(FamilyMember).where(
        FamilyMember.group_id == group_id, FamilyMember.user_id != user.id
    ).order_by(FamilyMember.joined_at, FamilyMember.id))).scalars().all()
    if me.role == "owner":
        if not others:
            await db.delete(me)
            await db.delete(group)
            await db.commit()
            return {"status": "deleted"}
        # Hand ownership to a guardian if there is one, otherwise the longest-standing member.
        heir = next((m for m in others if m.role == "guardian"), others[0])
        heir.role = "owner"
        group.owner_id = heir.user_id
    await db.delete(me)
    await db.commit()
    return {"status": "left"}


@router.delete("/groups/{group_id}")
async def delete_group(group_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    group, me = await _membership(group_id, user.id, db)
    _require(me, ("owner",), "delete the group")
    for m in (await db.execute(select(FamilyMember).where(FamilyMember.group_id == group_id))).scalars().all():
        await db.delete(m)
    await db.delete(group)
    await db.commit()
    return {"status": "deleted"}


@router.post("/groups/{group_id}/nudge")
async def nudge_member(group_id: int, data: Nudge, user: User = Depends(get_current_user),
                       db: AsyncSession = Depends(get_db)):
    group, me = await _membership(group_id, user.id, db)
    _require(me, MANAGER_ROLES, "send nudges")
    if data.member_user_id == user.id:
        raise HTTPException(status_code=400, detail="You can't nudge yourself")
    await _membership(group_id, data.member_user_id, db)
    if data.topic not in NUDGE_TOPICS:
        raise HTTPException(status_code=422, detail=f"topic must be one of {', '.join(NUDGE_TOPICS)}")
    title, default_message = NUDGE_TOPICS[data.topic]
    message = (data.message or "").strip() or default_message
    if not message:
        raise HTTPException(status_code=422, detail="Write a message for a custom nudge")
    db.add(Notification(user_id=data.member_user_id, title=f"{display_name(user)}: {title}",
                        message=f"{message} (from {group.name})", severity="warning"))
    await db.commit()
    return {"status": "sent"}


@router.get("/dashboard/{group_id}")
async def family_dashboard(group_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    group, me = await _membership(group_id, user.id, db)
    members = (await db.execute(
        select(FamilyMember).where(FamilyMember.group_id == group_id).order_by(FamilyMember.joined_at, FamilyMember.id)
    )).scalars().all()

    rows = []
    for m in members:
        u = await db.get(User, m.user_id)
        if u:
            rows.append({"user": u, "member": m, "snap": await member_snapshot(u, db)})

    member_out = []
    for row in rows:
        u, m, snap = row["user"], row["member"], row["snap"]
        is_me = u.id == user.id
        public = {k: v for k, v in snap.items() if not k.startswith("_")}
        if m.share_level != "detailed" and not is_me:
            public["top_issues"] = []
        member_out.append({
            "user_id": u.id,
            "username": u.username,
            "display_name": display_name(u),
            "role": m.role,
            "share_level": m.share_level,
            "is_me": is_me,
            "joined_at": m.joined_at.isoformat() if m.joined_at else None,
            **public,
        })

    snaps = [r["snap"] for r in rows]
    # Members with nothing tracked score 100 by default; leave them out so they don't hide real risk.
    tracked = [m for m in member_out if m["has_scanned"]]
    scores = [m["privacy_score"] for m in tracked]
    weakest = min(tracked, key=lambda m: m["privacy_score"], default=None)
    return {
        "group": _group_out(group, me, len(rows)),
        "summary": {
            "average_score": round(sum(scores) / len(scores)) if scores else 0,
            "lowest_score": min(scores, default=0),
            "member_count": len(rows),
            "total_accounts": sum(s["total_accounts"] for s in snaps),
            "accounts_at_risk": sum(s["accounts_at_risk"] for s in snaps),
            "breached_accounts": sum(s["breached_accounts"] for s in snaps),
            "accounts_without_2fa": sum(s["without_2fa"] for s in snaps),
            "darkweb_exposures": sum(s["darkweb_exposures"] for s in snaps),
            "members_needing_help": sum(1 for m in tracked if m["risk_level"] in ("critical", "high")),
            "weakest_member": weakest["display_name"] if weakest and len(tracked) > 1 else None,
            "members_not_tracking": len(rows) - len(tracked),
        },
        "members": member_out,
        **build_insights(rows, user.id),
        "nudge_topics": [{"id": k, "title": v[0]} for k, v in NUDGE_TOPICS.items()],
        "roles": list(ROLES),
    }
