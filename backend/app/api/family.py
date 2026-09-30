from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import secrets

from app.db.session import get_db
from app.models.user import User
from app.models.account import Account, FamilyGroup, FamilyMember
from app.core.security import get_current_user
from app.services.risk_engine import calculate_privacy_score

router = APIRouter(prefix="/family", tags=["family"])


class GroupCreate(BaseModel):
    name: str
    group_type: str = "family"


class InviteJoin(BaseModel):
    invite_code: str


@router.post("/groups")
async def create_group(
    data: GroupCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    invite_code = secrets.token_hex(6).upper()
    group = FamilyGroup(
        name=data.name,
        owner_id=user.id,
        group_type=data.group_type,
        invite_code=invite_code,
    )
    db.add(group)
    await db.commit()
    await db.refresh(group)

    member = FamilyMember(group_id=group.id, user_id=user.id, role="owner")
    db.add(member)
    await db.commit()

    return {
        "id": group.id,
        "name": group.name,
        "group_type": group.group_type,
        "invite_code": group.invite_code,
    }


@router.get("/groups")
async def list_groups(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    member_result = await db.execute(
        select(FamilyMember).where(FamilyMember.user_id == user.id)
    )
    memberships = member_result.scalars().all()
    group_ids = [m.group_id for m in memberships]

    if not group_ids:
        return []

    groups_result = await db.execute(
        select(FamilyGroup).where(FamilyGroup.id.in_(group_ids))
    )
    groups = groups_result.scalars().all()

    result = []
    for g in groups:
        members_result = await db.execute(
            select(FamilyMember).where(FamilyMember.group_id == g.id)
        )
        members = members_result.scalars().all()
        member_details = []
        for m in members:
            u_result = await db.execute(select(User).where(User.id == m.user_id))
            u = u_result.scalar_one_or_none()
            if u:
                member_details.append({
                    "user_id": u.id,
                    "username": u.username,
                    "full_name": u.full_name,
                    "privacy_score": u.privacy_score,
                    "role": m.role,
                })

        result.append({
            "id": g.id,
            "name": g.name,
            "group_type": g.group_type,
            "invite_code": g.invite_code if g.owner_id == user.id else None,
            "is_owner": g.owner_id == user.id,
            "members": member_details,
        })

    return result


@router.post("/join")
async def join_group(
    data: InviteJoin,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    group_result = await db.execute(
        select(FamilyGroup).where(FamilyGroup.invite_code == data.invite_code)
    )
    group = group_result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Invalid invite code")

    existing = await db.execute(
        select(FamilyMember).where(
            FamilyMember.group_id == group.id, FamilyMember.user_id == user.id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already a member")

    member = FamilyMember(group_id=group.id, user_id=user.id, role="member")
    db.add(member)
    await db.commit()
    return {"status": "joined", "group_name": group.name}


@router.delete("/groups/{group_id}/members/{member_user_id}")
async def remove_member(
    group_id: int,
    member_user_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    group_result = await db.execute(
        select(FamilyGroup).where(FamilyGroup.id == group_id, FamilyGroup.owner_id == user.id)
    )
    if not group_result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Only group owner can remove members")

    await db.execute(
        select(FamilyMember).where(
            FamilyMember.group_id == group_id, FamilyMember.user_id == member_user_id
        )
    )
    member_result = await db.execute(
        select(FamilyMember).where(
            FamilyMember.group_id == group_id, FamilyMember.user_id == member_user_id
        )
    )
    member = member_result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    await db.delete(member)
    await db.commit()
    return {"status": "removed"}


@router.get("/dashboard/{group_id}")
async def family_dashboard(
    group_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    check = await db.execute(
        select(FamilyMember).where(
            FamilyMember.group_id == group_id, FamilyMember.user_id == user.id
        )
    )
    if not check.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not a member of this group")

    members_result = await db.execute(
        select(FamilyMember).where(FamilyMember.group_id == group_id)
    )
    members = members_result.scalars().all()

    member_stats = []
    total_score = 0
    total_accounts = 0
    total_at_risk = 0

    for m in members:
        u_result = await db.execute(select(User).where(User.id == m.user_id))
        u = u_result.scalar_one_or_none()
        if not u:
            continue

        acc_result = await db.execute(select(Account).where(Account.user_id == u.id))
        accounts = acc_result.scalars().all()
        at_risk = sum(1 for a in accounts if a.risk_score >= 50)

        member_stats.append({
            "user_id": u.id,
            "username": u.username,
            "full_name": u.full_name,
            "privacy_score": u.privacy_score,
            "total_accounts": len(accounts),
            "accounts_at_risk": at_risk,
            "role": m.role,
        })
        total_score += u.privacy_score
        total_accounts += len(accounts)
        total_at_risk += at_risk

    avg_score = total_score // len(members) if members else 0

    return {
        "group_id": group_id,
        "average_score": avg_score,
        "total_accounts": total_accounts,
        "total_at_risk": total_at_risk,
        "members": member_stats,
    }
