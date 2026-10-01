import copy


def _account(client, headers, **a):
    client.post("/api/accounts/", headers=headers, json=a)


def test_zero_knowledge_proof_end_to_end(client, auth):
    headers, email = auth
    _account(client, headers, service_name="GitHub", category="work", has_2fa=True, twofa_method="passkey")
    score = client.get("/api/dashboard/", headers=headers).json()["privacy_score"]
    threshold = max(0, score - 10)

    res = client.post(f"/api/blockchain/zkp/prove?threshold={threshold}", headers=headers)
    assert res.status_code == 200, res.text
    package = res.json()["package"]
    assert str(score) not in str(package["credential"]) and "score" not in package["credential"]

    # Anyone can verify, without logging in.
    ok = client.post("/api/blockchain/zkp/verify", json=package).json()
    assert ok["valid"] is True and all(c["ok"] for c in ok["checks"])

    claimed_higher = {**package, "threshold": threshold + 5}
    assert client.post("/api/blockchain/zkp/verify", json=claimed_higher).json()["valid"] is False

    tampered = copy.deepcopy(package)
    tampered["proof"]["bit_proofs"][0]["z1"] = hex(int(tampered["proof"]["bit_proofs"][0]["z1"], 16) + 1)
    assert client.post("/api/blockchain/zkp/verify", json=tampered).json()["valid"] is False

    forged = copy.deepcopy(package)
    forged["credential"]["commitment"] = hex(int(forged["credential"]["commitment"], 16) + 2)
    assert client.post("/api/blockchain/zkp/verify", json=forged).json()["valid"] is False

    if score < 100:
        assert client.post(f"/api/blockchain/zkp/prove?threshold={score + 1}", headers=headers).status_code == 422
