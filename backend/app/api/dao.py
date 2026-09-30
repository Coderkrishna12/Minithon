from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.session import get_db
from app.models.user import User
from app.models.account import DAOProposal, DAOVote, Notification
from app.core.security import get_current_user
from app.services.blockchain import record_audit

router = APIRouter(prefix="/dao", tags=["dao"])


class ProposalCreate(BaseModel):
    title: str
    description: str
    service_name: str | None = None
    breach_date: str | None = None
    data_types_affected: list[str] = []
    evidence_url: str | None = None


class VoteCreate(BaseModel):
    vote: str


@router.get("/proposals")
async def list_proposals(
    status: str = "active",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(DAOProposal).order_by(DAOProposal.created_at.desc())
    if status != "all":
        query = query.where(DAOProposal.status == status)
    result = await db.execute(query)
    proposals = result.scalars().all()

    items = []
    for p in proposals:
        author_result = await db.execute(select(User).where(User.id == p.author_id))
        author = author_result.scalar_one_or_none()
        user_vote_result = await db.execute(
            select(DAOVote).where(DAOVote.proposal_id == p.id, DAOVote.user_id == user.id)
        )
        user_vote = user_vote_result.scalar_one_or_none()

        items.append({
            "id": p.id,
            "title": p.title,
            "description": p.description,
            "service_name": p.service_name,
            "breach_date": p.breach_date,
            "data_types_affected": p.data_types_affected,
            "evidence_url": p.evidence_url,
            "status": p.status,
            "votes_for": p.votes_for,
            "votes_against": p.votes_against,
            "author": author.username if author else "Unknown",
            "user_voted": user_vote.vote if user_vote else None,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        })

    return items


@router.post("/proposals")
async def create_proposal(
    data: ProposalCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    proposal = DAOProposal(
        author_id=user.id,
        title=data.title,
        description=data.description,
        service_name=data.service_name,
        breach_date=data.breach_date,
        data_types_affected=data.data_types_affected,
        evidence_url=data.evidence_url,
    )
    db.add(proposal)
    await db.commit()
    await db.refresh(proposal)

    await record_audit(
        user.id, "dao_proposal_created",
        f"Breach report proposal: {data.title}",
        {"proposal_id": proposal.id, "service": data.service_name},
        db,
    )

    return {"id": proposal.id, "title": proposal.title, "status": "active"}


@router.post("/proposals/{proposal_id}/vote")
async def vote_on_proposal(
    proposal_id: int,
    data: VoteCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if data.vote not in ("for", "against"):
        raise HTTPException(status_code=400, detail="Vote must be 'for' or 'against'")

    proposal_result = await db.execute(
        select(DAOProposal).where(DAOProposal.id == proposal_id)
    )
    proposal = proposal_result.scalar_one_or_none()
    if not proposal:
        raise HTTPException(status_code=404, detail="Proposal not found")

    existing = await db.execute(
        select(DAOVote).where(DAOVote.proposal_id == proposal_id, DAOVote.user_id == user.id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Already voted")

    vote = DAOVote(proposal_id=proposal_id, user_id=user.id, vote=data.vote)
    db.add(vote)

    if data.vote == "for":
        proposal.votes_for += 1
    else:
        proposal.votes_against += 1

    if proposal.votes_for >= 5:
        proposal.status = "confirmed"
        notif = Notification(
            user_id=proposal.author_id,
            title="Breach Report Confirmed by DAO",
            message=f"Your breach report '{proposal.title}' has been confirmed by community consensus.",
            severity="info",
        )
        db.add(notif)

    await db.commit()

    return {
        "status": "voted",
        "votes_for": proposal.votes_for,
        "votes_against": proposal.votes_against,
    }


@router.get("/stats")
async def dao_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    total_result = await db.execute(select(func.count(DAOProposal.id)))
    total = total_result.scalar() or 0

    active_result = await db.execute(
        select(func.count(DAOProposal.id)).where(DAOProposal.status == "active")
    )
    active = active_result.scalar() or 0

    confirmed_result = await db.execute(
        select(func.count(DAOProposal.id)).where(DAOProposal.status == "confirmed")
    )
    confirmed = confirmed_result.scalar() or 0

    votes_result = await db.execute(select(func.count(DAOVote.id)))
    total_votes = votes_result.scalar() or 0

    return {
        "total_proposals": total,
        "active_proposals": active,
        "confirmed_breaches": confirmed,
        "total_votes": total_votes,
    }
