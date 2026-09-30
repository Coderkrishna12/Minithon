import asyncio
import hashlib
import json
import logging
from collections import defaultdict
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.account import AuditLog, ChainAnchor
from app.services.identity import issuer_did, sign_payload

log = logging.getLogger(__name__)
settings = get_settings()

GENESIS_HASH = "0" * 64
_user_locks: dict[int, asyncio.Lock] = defaultdict(asyncio.Lock)


def compute_hash(data: dict) -> str:
    serialized = json.dumps(data, sort_keys=True, default=str)
    return hashlib.sha256(serialized.encode()).hexdigest()


def _timestamp(dt: datetime) -> str:
    """SQLite drops tzinfo on read, so hash a fixed UTC format rather than isoformat()."""
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def block_hash(index: int, previous_hash: str, data_hash: str, action: str, timestamp: str) -> str:
    return compute_hash({
        "index": index,
        "previous_hash": previous_hash,
        "data_hash": data_hash,
        "action": action,
        "timestamp": timestamp,
    })


def _send_anchor_tx(digest: str) -> tuple[str, int]:
    """Write the block hash into a zero-value self-transfer so it is publicly timestamped."""
    from web3 import Web3

    w3 = Web3(Web3.HTTPProvider(settings.polygon_rpc_url, request_kwargs={"timeout": 20}))
    account = w3.eth.account.from_key(settings.polygon_private_key)
    chain_id = w3.eth.chain_id
    tx = {
        "to": account.address,
        "value": 0,
        "data": "0x" + digest,
        "nonce": w3.eth.get_transaction_count(account.address, "pending"),
        "chainId": chain_id,
        "gas": 30000,
        "gasPrice": w3.eth.gas_price,
    }
    signed = account.sign_transaction(tx)
    return w3.eth.send_raw_transaction(signed.raw_transaction).hex(), chain_id


async def _anchor(entry: AuditLog, db: AsyncSession) -> None:
    if not settings.polygon_private_key:
        return
    try:
        tx_hash, chain_id = await asyncio.to_thread(_send_anchor_tx, entry.blockchain_tx_hash)
    except Exception:
        log.exception("Anchoring block %s failed", entry.blockchain_block)
        return
    db.add(ChainAnchor(audit_log_id=entry.id, network_tx_hash=tx_hash, chain_id=chain_id))
    await db.commit()


async def record_audit(user_id: int, action: str, details: str, data: dict, db: AsyncSession) -> AuditLog:
    async with _user_locks[user_id]:
        last = (await db.execute(
            select(AuditLog).where(AuditLog.user_id == user_id).order_by(AuditLog.blockchain_block.desc()).limit(1)
        )).scalar_one_or_none()
        index = (last.blockchain_block or 0) + 1 if last else 1
        previous = last.blockchain_tx_hash if last else GENESIS_HASH
        now = datetime.now(timezone.utc).replace(microsecond=0)
        data_hash = compute_hash(data)

        entry = AuditLog(
            user_id=user_id,
            action=action,
            details=details,
            data_hash=data_hash,
            blockchain_tx_hash=block_hash(index, previous, data_hash, action, _timestamp(now)),
            blockchain_block=index,
            created_at=now,
        )
        db.add(entry)
        await db.commit()
        await db.refresh(entry)

    await _anchor(entry, db)
    return entry


async def user_chain(user_id: int, db: AsyncSession) -> dict:
    """Every block for the user, each re-hashed from stored fields and checked against its predecessor."""
    rows = (await db.execute(
        select(AuditLog).where(AuditLog.user_id == user_id).order_by(AuditLog.blockchain_block, AuditLog.id)
    )).scalars().all()
    anchors = {
        a.audit_log_id: a
        for a in (await db.execute(
            select(ChainAnchor).where(ChainAnchor.audit_log_id.in_([r.id for r in rows]))
        )).scalars().all()
    } if rows else {}

    blocks = []
    previous = GENESIS_HASH
    broken_at = None
    for row in rows:
        ts = _timestamp(row.created_at)
        expected = block_hash(row.blockchain_block, previous, row.data_hash, row.action, ts)
        intact = expected == row.blockchain_tx_hash
        if not intact and broken_at is None:
            broken_at = row.blockchain_block
        anchor = anchors.get(row.id)
        blocks.append({
            "index": row.blockchain_block,
            "timestamp": ts,
            "data": {"action": row.action, "data_hash": row.data_hash},
            "previous_hash": previous,
            "hash": row.blockchain_tx_hash,
            "intact": intact,
            "anchor": {
                "tx_hash": anchor.network_tx_hash,
                "chain_id": anchor.chain_id,
                "url": settings.polygon_explorer_tx_url + anchor.network_tx_hash,
            } if anchor else None,
        })
        previous = row.blockchain_tx_hash

    return {
        "chain": blocks,
        "length": len(blocks),
        "valid": broken_at is None,
        "broken_at": broken_at,
        "anchoring": bool(settings.polygon_private_key),
    }


def score_attestation(user_id: int, privacy_score: int, threshold: int) -> dict:
    """Issuer-signed statement that the score meets a threshold. Reveals the result, not the score."""
    issued_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    statement = {
        "issuer": issuer_did(),
        "subject": f"privacyshield:user:{user_id}",
        "claim": f"privacy_score >= {threshold}",
        "result": privacy_score >= threshold,
        "issued_at": issued_at,
    }
    return {
        "verified": statement["result"],
        "claim": f"Privacy score meets or exceeds {threshold}",
        "timestamp": issued_at,
        "statement": statement,
        "proof": sign_payload(statement),
    }
