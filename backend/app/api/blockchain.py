import asyncio
import json
import time
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User
from app.models.account import AuditLog, ZkCredential
from app.core.security import get_current_user
from app.services.blockchain import record_audit, score_attestation, user_chain
from app.services.identity import issuer_did, sign_payload, verify_payload
from app.services.risk_engine import calculate_privacy_score
from app.services.zkp import new_commitment, prove_at_least, verify_at_least

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


# ── Zero-knowledge proof: "my privacy score is at least T" without revealing the score ──

class ZkPackage(BaseModel):
    credential: dict
    signature: dict
    threshold: int
    proof: dict


@router.post("/zkp/prove")
async def zkp_prove(
    threshold: int = Query(default=70, ge=0, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Commit to the current score, sign the commitment, and prove score >= threshold in zero knowledge."""
    score = await calculate_privacy_score(user.id, db)
    user.privacy_score = score
    if score < threshold:
        raise HTTPException(
            status_code=422,
            detail=f"Your score is below {threshold}, so a valid proof cannot exist. Try a lower threshold or raise your score.",
        )
    started = time.perf_counter()
    commitment, randomness = new_commitment(score)
    credential = {
        "type": "PrivacyScoreCommitment",
        "issuer": issuer_did(),
        "subject": f"privacyshield:user:{user.id}",
        "commitment": hex(commitment),
        "scheme": "pedersen/rfc3526-modp-2048",
        "issued_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    signature = sign_payload(credential)
    proof = await asyncio.to_thread(prove_at_least, score, randomness, commitment, threshold, signature["proofValue"])
    db.add(ZkCredential(user_id=user.id, commitment=hex(commitment), randomness=hex(randomness), score=score,
                        credential=credential))
    await record_audit(user.id, "zkp_proof_issued", f"Zero-knowledge proof issued: score >= {threshold}",
                       {"commitment": hex(commitment), "threshold": threshold}, db)
    package = {"credential": credential, "signature": signature, "threshold": threshold, "proof": proof}
    return {
        "claim": f"Privacy score is at least {threshold}",
        "package": package,
        "proof_bytes": len(json.dumps(package)),
        "generated_ms": round((time.perf_counter() - started) * 1000),
        "reveals": ["that the score is at least the threshold"],
        "hides": ["the score itself", "the commitment randomness"],
    }


@router.post("/zkp/verify")
async def zkp_verify(data: ZkPackage):
    """Public: anyone can check a proof. They learn only whether the score meets the threshold."""
    started = time.perf_counter()
    checks = []
    signed = verify_payload(data.credential, data.signature) and data.credential.get("issuer") == issuer_did()
    checks.append({"check": "Commitment signed by the PrivacyShield issuer (Ed25519)", "ok": signed})
    try:
        commitment = int(str(data.credential.get("commitment", "")), 16)
    except ValueError:
        commitment = 0
    valid, reason = (False, "Skipped: the credential signature is not valid")
    if signed and commitment:
        valid, reason = await asyncio.to_thread(
            verify_at_least, commitment, data.threshold, data.proof, data.signature.get("proofValue", ""))
    checks.append({"check": f"Range proof: committed score - {data.threshold} is in [0, 127]", "ok": valid})
    return {
        "valid": signed and valid,
        "claim": f"Privacy score is at least {data.threshold}",
        "reason": reason if signed else "The credential was not signed by this issuer, or it was altered",
        "checks": checks,
        "issuer": issuer_did(),
        "verified_ms": round((time.perf_counter() - started) * 1000),
    }
