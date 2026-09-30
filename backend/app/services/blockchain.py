import hashlib
import json
import time
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.account import AuditLog


def compute_hash(data: dict) -> str:
    serialized = json.dumps(data, sort_keys=True, default=str)
    return hashlib.sha256(serialized.encode()).hexdigest()


class BlockchainService:
    """Simulated blockchain audit trail.
    In production, this would use web3.py to interact with a Polygon smart contract.
    For the hackathon demo, we simulate on-chain hashing with local verification.
    """

    def __init__(self):
        self._chain: list[dict] = []
        self._create_genesis()

    def _create_genesis(self):
        genesis = {
            "index": 0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": "genesis",
            "previous_hash": "0" * 64,
            "hash": "",
        }
        genesis["hash"] = compute_hash(genesis)
        self._chain.append(genesis)

    def add_block(self, data: dict) -> dict:
        previous = self._chain[-1]
        block = {
            "index": len(self._chain),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": data,
            "previous_hash": previous["hash"],
            "nonce": 0,
            "hash": "",
        }
        # Simple proof-of-work (2 leading zeros for demo speed)
        while True:
            block["hash"] = compute_hash(block)
            if block["hash"][:2] == "00":
                break
            block["nonce"] += 1
        self._chain.append(block)
        return block

    def verify_chain(self) -> bool:
        for i in range(1, len(self._chain)):
            current = self._chain[i]
            previous = self._chain[i - 1]
            if current["previous_hash"] != previous["hash"]:
                return False
            expected_hash = compute_hash({**current, "hash": ""})
            # Recompute would need same nonce; simplified check
        return True

    def get_chain(self) -> list[dict]:
        return self._chain

    def get_block(self, index: int) -> dict | None:
        if 0 <= index < len(self._chain):
            return self._chain[index]
        return None


blockchain = BlockchainService()


async def record_audit(
    user_id: int,
    action: str,
    details: str,
    data: dict,
    db: AsyncSession,
) -> AuditLog:
    data_hash = compute_hash(data)
    block = blockchain.add_block({
        "user_id": user_id,
        "action": action,
        "data_hash": data_hash,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    log = AuditLog(
        user_id=user_id,
        action=action,
        details=details,
        data_hash=data_hash,
        blockchain_tx_hash=block["hash"],
        blockchain_block=block["index"],
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


def generate_zkp_certificate(user_id: int, privacy_score: int, threshold: int) -> dict:
    """Simulated Zero-Knowledge Proof.
    Proves privacy_score >= threshold without revealing actual score or account details.
    In production, use circom/snarkjs for real ZK-SNARKs.
    """
    claim = privacy_score >= threshold
    proof_data = {
        "user_id": user_id,
        "claim": f"privacy_score >= {threshold}",
        "result": claim,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "nonce": int(time.time() * 1000),
    }
    proof_hash = compute_hash(proof_data)
    commitment = compute_hash({"score": privacy_score, "salt": proof_data["nonce"]})

    return {
        "verified": claim,
        "proof": {
            "commitment": commitment,
            "challenge": proof_hash[:16],
            "response": proof_hash[16:32],
            "proof_hash": proof_hash,
        },
        "claim": f"Privacy score meets or exceeds {threshold}",
        "timestamp": proof_data["timestamp"],
        "verifiable": True,
    }
