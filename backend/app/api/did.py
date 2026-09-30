from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone

from app.db.session import get_db
from app.models.user import User
from app.models.account import DIDIdentity
from app.core.security import get_current_user
from app.services.blockchain import record_audit
from app.services.identity import issuer_did, new_keypair, private_key_b64, raw_public, sign_payload, verify_payload

router = APIRouter(prefix="/did", tags=["did"])


def _credential(subject_did: str, credential_type: str, privacy_score: int) -> dict:
    body = {
        "type": credential_type,
        "issuer": issuer_did(),
        "subject": subject_did,
        "issuance_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "privacy_score": privacy_score,
    }
    return {**body, "proof": sign_payload(body)}


def _credential_valid(credential: dict) -> bool:
    body = {k: v for k, v in credential.items() if k != "proof"}
    return isinstance(credential.get("proof"), dict) and verify_payload(body, credential["proof"])


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

    private_key, did_string = new_keypair()
    public_key = raw_public(private_key.public_key()).hex()

    did = DIDIdentity(
        user_id=user.id,
        did_string=did_string,
        public_key=public_key,
        verification_method=f"{did_string}#{did_string.removeprefix('did:key:')}",
        credentials=[_credential(did_string, "PrivacyScoreCredential", user.privacy_score)],
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
        "private_key": private_key_b64(private_key),
        "private_key_notice": "Shown once. PrivacyShield does not store it; save it to prove control of this DID.",
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

    credentials = did.credentials or []
    valid = [c for c in credentials if _credential_valid(c)]
    return {
        "verified": did.is_active and len(valid) == len(credentials),
        "did": did.did_string,
        "is_active": did.is_active,
        "issuer": issuer_did(),
        "credentials_count": len(credentials),
        "credentials_valid": len(valid),
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

    credential = _credential(did.did_string, credential_type, user.privacy_score)

    creds = list(did.credentials or [])
    creds.append(credential)
    did.credentials = creds
    await db.commit()

    return {"credential": credential}
