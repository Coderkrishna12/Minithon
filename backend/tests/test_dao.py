import secrets
import pytest


def test_dao_proposal_and_voting(client, auth):
    headers, _ = auth

    # 1. Create a proposal
    create_resp = client.post(
        "/api/dao/proposals",
        headers=headers,
        json={
            "title": "Data Leak in Cloud Service",
            "service_name": "CloudX",
            "description": "API keys leaked on public paste site",
            "evidence_url": "https://example.com/paste/123",
        },
    )
    assert create_resp.status_code == 200
    prop_data = create_resp.json()
    assert "id" in prop_data
    proposal_id = prop_data["id"]
    assert prop_data["status"] == "active"

    # 2. Vote 'for'
    vote_resp = client.post(
        f"/api/dao/proposals/{proposal_id}/vote",
        headers=headers,
        json={"vote": "for"},
    )
    assert vote_resp.status_code == 200
    vote_data = vote_resp.json()
    assert vote_data["status"] == "voted"
    assert vote_data["votes_for"] == 1
    assert vote_data["votes_against"] == 0

    # 3. Prevent duplicate vote from same user
    dup_resp = client.post(
        f"/api/dao/proposals/{proposal_id}/vote",
        headers=headers,
        json={"vote": "for"},
    )
    assert dup_resp.status_code == 400
    assert "Already voted" in dup_resp.json()["detail"]

    # 4. Reject invalid vote option
    email = f"user2_{secrets.token_hex(4)}@example.com"
    client.post("/api/auth/register", json={"email": email, "username": email.split("@")[0], "password": "password123"})
    token2 = client.post("/api/auth/login", json={"email": email, "password": "password123"}).json()["access_token"]
    headers2 = {"Authorization": f"Bearer {token2}"}

    invalid_resp = client.post(
        f"/api/dao/proposals/{proposal_id}/vote",
        headers=headers2,
        json={"vote": "maybe"},
    )
    assert invalid_resp.status_code == 400

    # 5. Nonexistent proposal vote returns 404
    nf_resp = client.post(
        "/api/dao/proposals/99999/vote",
        headers=headers2,
        json={"vote": "for"},
    )
    assert nf_resp.status_code == 404
