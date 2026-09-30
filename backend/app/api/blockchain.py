from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import AuditLog
from app.core.security import get_current_user
from app.services.blockchain import blockchain, record_audit, generate_zkp_certificate

router = APIRouter(prefix="/blockchain", tags=["blockchain"])


@router.get("/chain")
async def get_chain():
    return {"chain": blockchain.get_chain(), "length": len(blockchain.get_chain()), "valid": blockchain.verify_chain()}


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
async def verify_block(block_index: int):
    block = blockchain.get_block(block_index)
    if not block:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Block not found")
    return {"block": block, "chain_valid": blockchain.verify_chain()}


@router.post("/zkp-certificate")
async def generate_zkp(
    threshold: int = Query(default=70, ge=0, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    certificate = generate_zkp_certificate(user.id, user.privacy_score, threshold)

    await record_audit(
        user.id, "zkp_certificate_generated",
        f"ZKP certificate generated for threshold {threshold}",
        {"threshold": threshold, "result": certificate["verified"]},
        db,
    )

    return certificate
