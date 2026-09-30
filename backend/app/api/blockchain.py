from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import AuditLog
from app.core.security import get_current_user
from app.services.blockchain import record_audit, score_attestation, user_chain
from app.services.identity import issuer_did, verify_payload

router = APIRouter(prefix="/blockchain", tags=["blockchain"])


class AttestationCheck(BaseModel):
    statement: dict
    proof: dict


@router.get("/chain")
async def get_chain(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await user_chain(user.id, db)


@router.get("/audit-log")
async def get_audit_log(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AuditLog).where(AuditLog.user_id == user.id).order_by(AuditLog.created_at.desc())
    )
    logs = result.scalars().all()
    return [
        {
            "id": log.id,
            "action": log.action,
            "details": log.details,
            "data_hash": log.data_hash,
            "blockchain_tx_hash": log.blockchain_tx_hash,
            "blockchain_block": log.blockchain_block,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log in logs
    ]


@router.post("/record-audit")
async def create_audit(
    action: str,
    details: str = "",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = await record_audit(user.id, action, details, {"user_id": user.id, "action": action}, db)
    return {
        "id": log.id,
        "action": log.action,
        "data_hash": log.data_hash,
        "blockchain_tx_hash": log.blockchain_tx_hash,
        "blockchain_block": log.blockchain_block,
    }


@router.get("/verify/{block_index}")
async def verify_block(
    block_index: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    chain = await user_chain(user.id, db)
    block = next((b for b in chain["chain"] if b["index"] == block_index), None)
    if not block:
        raise HTTPException(status_code=404, detail="Block not found")
    return {"block": block, "chain_valid": chain["valid"]}


@router.post("/zkp-certificate")
async def generate_attestation(
    threshold: int = Query(default=70, ge=0, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    attestation = score_attestation(user.id, user.privacy_score, threshold)
    await record_audit(
        user.id, "score_attestation_issued",
        f"Signed attestation issued for threshold {threshold}",
        attestation["statement"],
        db,
    )
    return attestation


@router.post("/attestations/verify")
async def verify_attestation(data: AttestationCheck):
    """Public: anyone holding an attestation can check it was signed by this server's issuer key."""
    valid = verify_payload(data.statement, data.proof) and data.statement.get("issuer") == issuer_did()
    return {"valid": valid, "issuer": issuer_did()}
