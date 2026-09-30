from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
import hashlib
import secrets

from app.db.session import get_db
from app.models.user import User
from app.models.account import DIDIdentity
from app.core.security import get_current_user
from app.services.blockchain import record_audit, compute_hash

router = APIRouter(prefix="/did", tags=["did"])


def _generate_did(user_id: int) -> tuple[str, str]:
    private_seed = secrets.token_hex(32)
    public_key = hashlib.sha256(private_seed.encode()).hexdigest()
    did_string = f"did:privacyshield:{public_key[:32]}"
    return did_string, public_key


@router.post("/create")
async def create_did(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(DIDIdentity).where(DIDIdentity.user_id == user.id, DIDIdentity.is_active == True)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Active DID already exists")

    did_string, public_key = _generate_did(user.id)

    did = DIDIdentity(
        user_id=user.id,
        did_string=did_string,
        public_key=public_key,
        verification_method=f"{did_string}#key-1",
        credentials=[{
            "type": "PrivacyScoreCredential",
            "issuer": "did:privacyshield:system",
            "issuance_date": datetime.now(timezone.utc).isoformat(),
            "privacy_score": user.privacy_score,
        }],
    )
    db.add(did)
    await db.commit()
    await db.refresh(did)

    await record_audit(
        user.id, "did_created",
        f"Decentralized identity created: {did_string}",
        {"did": did_string},
        db,
    )

    return {
        "id": did.id,
        "did": did.did_string,
        "public_key": did.public_key,
        "verification_method": did.verification_method,
        "credentials": did.credentials,
        "document": {
            "@context": "https://www.w3.org/ns/did/v1",
            "id": did.did_string,
            "verificationMethod": [{
                "id": did.verification_method,
                "type": "Ed25519VerificationKey2020",
                "controller": did.did_string,
                "publicKeyHex": did.public_key,
            }],
            "authentication": [did.verification_method],
        },
    }


@router.get("/")
async def get_did(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DIDIdentity).where(DIDIdentity.user_id == user.id, DIDIdentity.is_active == True)
    )
    did = result.scalar_one_or_none()
    if not did:
        return {"has_did": False}

    return {
        "has_did": True,
        "id": did.id,
        "did": did.did_string,
        "public_key": did.public_key,
        "verification_method": did.verification_method,
        "credentials": did.credentials,
        "created_at": did.created_at.isoformat() if did.created_at else None,
    }


@router.post("/verify")
async def verify_did(
    did_string: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DIDIdentity).where(DIDIdentity.did_string == did_string)
    )
    did = result.scalar_one_or_none()

    if not did:
        return {"verified": False, "reason": "DID not found"}

    proof_hash = compute_hash({"did": did.did_string, "key": did.public_key})

    return {
        "verified": True,
        "did": did.did_string,
        "is_active": did.is_active,
        "proof_hash": proof_hash,
        "credentials_count": len(did.credentials or []),
    }


@router.post("/issue-credential")
async def issue_credential(
    credential_type: str = "PrivacyScoreCredential",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(DIDIdentity).where(DIDIdentity.user_id == user.id, DIDIdentity.is_active == True)
    )
    did = result.scalar_one_or_none()
    if not did:
        raise HTTPException(status_code=400, detail="Create a DID first")

    credential = {
        "type": credential_type,
        "issuer": "did:privacyshield:system",
        "issuance_date": datetime.now(timezone.utc).isoformat(),
        "privacy_score": user.privacy_score,
        "proof": compute_hash({
            "did": did.did_string,
            "score": user.privacy_score,
            "type": credential_type,
        }),
    }

    creds = list(did.credentials or [])
    creds.append(credential)
    did.credentials = creds
    await db.commit()

    return {"credential": credential}
