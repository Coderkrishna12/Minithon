from app.services.risk_engine import score_network


def test_unknown_security_state_is_not_assumed_to_be_secure_or_disabled():
    unknown = {"id": 1, "category": None, "has_2fa": None, "permissions": [], "breach_count": 0}
    _, components, _ = score_network([unknown], [])
    assert components[1]["missing_2fa"] == 50
    assert components[1]["model_version"] == "deterministic-2"


def test_risk_model_is_deterministic_and_applies_keystone_floor():
    accounts = [{"id": i, "category": "other", "has_2fa": None, "permissions": [], "breach_count": 0} for i in range(1, 7)]
    edges = [{"from_account_id": 1, "to_account_id": i, "connection_type": "recovery_email"} for i in range(2, 7)]
    first = score_network(accounts, edges)
    second = score_network(accounts, edges)
    assert first == second
    assert first[1][1]["keystone"] is True
    assert first[1][1]["keystone_floor"] == 75
    assert first[0][1] >= 75


def test_fixture_accounts_keep_uncertainty_and_do_not_attach_real_email(client, auth, mock_http):
    headers, email = auth
    response = client.post("/api/import/fixture-mailbox/scan", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert payload["mode"] == "fixture"
    assert "DEMO DATA" in payload["label"]
    newsletter = next(row for row in payload["discovered"] if "Newsletter" in row["service_name"])
    assert newsletter["importable"] is False

    created = client.post("/api/import/bulk-add", headers=headers, json={
        "services": ["GitHub"], "added_via": "fixture_mailbox", "import_confidence": 0.9,
    })
    assert created.status_code == 200, created.text
    imported = next(a for a in client.get("/api/accounts/", headers=headers).json() if a["service_name"] == "GitHub")
    assert imported["has_2fa"] is None
    assert imported["login_method"] == "unknown"
    assert imported["email_used"] is None
    assert email not in str(imported)


def test_password_csv_api_rejects_plaintext_password_fields(client, auth):
    headers, _ = auth
    rejected = client.post("/api/import/password-manager-csv", headers=headers, json={
        "services": [{"service_name": "Demo", "password_group": "reuse_1", "password": "never-send-me"}],
    })
    assert rejected.status_code == 422
    accepted = client.post("/api/import/password-manager-csv", headers=headers, json={
        "services": [
            {"service_name": "Site A", "password_group": "reuse_1"},
            {"service_name": "Site B", "password_group": "reuse_1"},
        ],
    })
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["plaintext_received"] is False
    accounts = client.get("/api/accounts/", headers=headers).json()
    rows = [a for a in accounts if a["added_via"] == "local_password_manager_csv"]
    assert {a["password_group"] for a in rows} == {"reuse_1"}
    assert all(a["email_used"] is None and a["has_2fa"] is None for a in rows)


def test_fix_preview_completion_and_audit_receipt_match(client, auth):
    headers, _ = auth
    account = client.post("/api/accounts/", headers=headers, json={
        "service_name": "Fix target", "has_2fa": False, "category": "email",
    }).json()
    client.post("/api/accounts/", headers=headers, json={
        "service_name": "Shared password", "password_group": "shared", "has_2fa": None,
    })
    # Create a reuse edge through the derived graph builder.
    # Account creation already refreshes the graph; the identical group is the modeled signal.
    fixes = client.get("/api/dashboard/fixes", headers=headers).json()
    fix = next(item for item in fixes if item["account_id"] == account["id"] and item["action_type"] == "enable_2fa")
    preview = client.get(f"/api/dashboard/fixes/{fix['id']}/preview", headers=headers)
    assert preview.status_code == 200, preview.text
    before = client.get("/api/dashboard/", headers=headers).json()["privacy_score"]
    assert preview.json()["before_score"] == before
    assert preview.json()["changes_external_account"] is False
    completed = client.patch(f"/api/dashboard/fixes/{fix['id']}/complete", headers=headers)
    assert completed.status_code == 200, completed.text
    after = client.get("/api/dashboard/", headers=headers).json()["privacy_score"]
    assert after == preview.json()["after_score"]
    chain = client.get("/api/blockchain/chain", headers=headers).json()
    assert chain["valid"] is True
    assert any(block["hash"] == completed.json()["blockchain_tx_hash"] for block in chain["chain"])
