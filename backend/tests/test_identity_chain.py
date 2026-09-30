import os
import sqlite3


def _db_path() -> str:
    return os.environ["DATABASE_URL"].split("///", 1)[1]


def test_audit_chain_detects_tampering(client, auth):
    headers, _ = auth
    for action in ("scan", "fix", "export"):
        assert client.post(f"/api/blockchain/record-audit?action={action}", headers=headers).status_code == 200

    chain = client.get("/api/blockchain/chain", headers=headers).json()
    assert chain["valid"] is True
    assert [b["index"] for b in chain["chain"]] == [1, 2, 3]
    assert chain["chain"][1]["previous_hash"] == chain["chain"][0]["hash"]

    with sqlite3.connect(_db_path()) as conn:
        conn.execute("UPDATE audit_logs SET action = 'nothing-happened' WHERE blockchain_block = 2")

    tampered = client.get("/api/blockchain/chain", headers=headers).json()
    assert tampered["valid"] is False
    assert tampered["broken_at"] == 2


def test_chain_requires_login(client):
    assert client.get("/api/blockchain/chain").status_code in (401, 403)


def test_score_attestation_is_signed_and_verifiable(client, auth):
    headers, _ = auth
    attestation = client.post("/api/blockchain/zkp-certificate?threshold=0", headers=headers).json()
    assert attestation["verified"] is True

    check = {"statement": attestation["statement"], "proof": attestation["proof"]}
    assert client.post("/api/blockchain/attestations/verify", json=check).json()["valid"] is True

    forged = {**check, "statement": {**attestation["statement"], "claim": "privacy_score >= 99"}}
    assert client.post("/api/blockchain/attestations/verify", json=forged).json()["valid"] is False


def test_did_uses_real_keys_and_signed_credentials(client, auth):
    headers, _ = auth
    created = client.post("/api/did/create", headers=headers).json()

    assert created["did"].startswith("did:key:z6Mk")
    assert created["private_key"]
    assert "private_key" not in client.get("/api/did/", headers=headers).json()

    verified = client.post(f"/api/did/verify?did_string={created['did']}", headers=headers).json()
    assert verified["verified"] is True
    assert verified["credentials_valid"] == 1


def test_badges_cannot_be_minted_without_eligibility(client, auth):
    headers, _ = auth
    assert client.post("/api/features/badges/mint/breach_free", headers=headers).status_code == 403
    minted = client.post("/api/features/badges/mint/first_audit", headers=headers)
    assert minted.status_code == 200
    assert client.get("/api/blockchain/chain", headers=headers).json()["length"] == 1
