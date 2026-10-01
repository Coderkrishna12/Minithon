from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.core.security import get_current_user
from app.services.rag import pipeline as rag
from app.services.ai_engine import (
    analyze_privacy_policy, fetch_policy_text, predict_breach_probability,
    smart_permission_advisor, digital_twin_simulation,
)
from sqlalchemy import select
from app.models.account import Account

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatMessage(BaseModel):
    message: str
    history: list[dict] = []


class PolicyAnalysisRequest(BaseModel):
    url: str


@router.post("/chat")
async def ai_chat(
    data: ChatMessage,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve the user's records and HIBP breach entries relevant to the question, then answer with citations."""
    return await rag.answer(user.id, data.message, data.history, db)


@router.get("/rag/status")
async def rag_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await rag.index_status(user.id, db)


@router.post("/rag/reindex")
async def rag_reindex(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    warnings = await rag.ensure_indexed(user.id, db)
    return {**(await rag.index_status(user.id, db)), "warnings": warnings}


@router.post("/analyze-policy")
async def analyze_policy(
    data: PolicyAnalysisRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    text = await fetch_policy_text(data.url)
    await rag.index_policy(user.id, data.url, text, db)
    return await analyze_privacy_policy(data.url, text)


@router.get("/breach-predictions")
async def breach_predictions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Account).where(Account.user_id == user.id))
    accounts = result.scalars().all()

    predictions = []
    for a in accounts:
        pred = predict_breach_probability({
            "service_name": a.service_name,
            "category": a.category,
            "breach_count": a.breach_count,
            "has_2fa": a.has_2fa,
            "password_group": a.password_group,
        })
        predictions.append(pred)

    predictions.sort(key=lambda p: p["probability_6_months"], reverse=True)
    return predictions


@router.get("/permission-advisor")
async def permission_advisor(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    recommendations = await smart_permission_advisor(user.id, db)
    return {"recommendations": recommendations, "total": len(recommendations)}


@router.post("/digital-twin")
async def digital_twin(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await digital_twin_simulation(user.id, db)
    return result
