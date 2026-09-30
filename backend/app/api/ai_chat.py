from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.core.security import get_current_user
from app.services.ai_engine import (
    AIUnavailable, chat_with_ai, analyze_privacy_policy, predict_breach_probability,
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
    try:
        response = await chat_with_ai(user.id, data.message, data.history, db)
    except AIUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"response": response}


@router.post("/analyze-policy")
async def analyze_policy(
    data: PolicyAnalysisRequest,
    user: User = Depends(get_current_user),
):
    result = await analyze_privacy_policy(data.url)
    return result


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
