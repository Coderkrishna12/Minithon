from app.services.attack_simulator import hop_success, report, simulate


def add(client, headers, **account):
    return client.post("/api/accounts/", headers=headers, json=account).json()["id"]


def network(client, headers, email):
    ids = {
        "gmail": add(client, headers, service_name="Gmail", service_url="gmail.com", category="email",
                     email_used=email, has_2fa=False, password_group="shared"),
        "bank": add(client, headers, service_name="HDFC Bank", category="finance", email_used=email, has_2fa=False),
        "netflix": add(client, headers, service_name="Netflix", category="entertainment", login_method="google_sso"),
        "dropbox": add(client, headers, service_name="Dropbox", category="cloud", has_2fa=True, twofa_method="totp",
                       password_group="shared"),
        "insta": add(client, headers, service_name="Instagram", category="social", has_2fa=False,
                     password_group="shared", permissions=["location", "contacts"]),
    }
    return ids


def test_two_factor_changes_whether_a_hop_works():
    assert hop_success("password_reuse", {"has_2fa": False}) > 0.8
    assert hop_success("password_reuse", {"has_2fa": True, "twofa_method": "totp"}) < 0.15
    assert hop_success("password_reuse", {"has_2fa": True, "twofa_method": "sms"}) > hop_success(
        "password_reuse", {"has_2fa": True, "twofa_method": "passkey"})
    assert hop_success("sso", {"has_2fa": True}) == hop_success("sso", {"has_2fa": False})


def test_attack_follows_direction_and_is_stopped_by_2fa():
    accounts = [
        {"id": 1, "service_name": "Mail", "category": "email", "has_2fa": False},
        {"id": 2, "service_name": "Bank", "category": "finance", "has_2fa": False},
        {"id": 3, "service_name": "Cloud", "category": "cloud", "has_2fa": True, "twofa_method": "passkey"},
    ]
    edges = [
        {"from_account_id": 1, "to_account_id": 2, "connection_type": "recovery_email"},
        {"from_account_id": 1, "to_account_id": 3, "connection_type": "recovery_email"},
    ]
    from_mail = report(accounts, simulate(accounts, edges, 1))
    assert [s["to"] for s in from_mail["steps"]] == ["Bank"]
    assert from_mail["blocked"][0]["to"] == "Cloud" and "passkey" in from_mail["blocked"][0]["explanation"]
    assert from_mail["damage"]["financial_accounts_at_risk"][0]["service"] == "Bank"
    # Recovery links only run one way: owning the bank doesn't open the mailbox.
    assert report(accounts, simulate(accounts, edges, 2))["steps"] == []


def test_run_reports_damage_and_shrinks_after_fixes(client, auth):
    headers, email = auth
    ids = network(client, headers, email)

    points = client.get("/api/attack-sim/entry-points", headers=headers).json()
    # Dropbox has 2FA itself, but its password also opens Gmail (no 2FA), which opens everything else.
    assert points["suggested_id"] == ids["dropbox"]
    reach = {p["id"]: p["reaches"] for p in points["entry_points"]}
    assert reach[ids["dropbox"]] == 4 and reach[ids["gmail"]] == 3 and reach[ids["bank"]] == 0

    res = client.post("/api/attack-sim/run", headers=headers, json={"entry_account_id": ids["gmail"]}).json()
    before = res["before"]
    reached = {s["to"] for s in before["steps"]}
    assert {"HDFC Bank", "Netflix", "Instagram"} <= reached
    assert "Dropbox" not in reached
    assert any(b["to"] == "Dropbox" for b in before["blocked"])
    vias = {s["to"]: s["via"] for s in before["steps"]}
    assert vias["HDFC Bank"] == "recovery_email" and vias["Netflix"] == "sso" and vias["Instagram"] == "password_reuse"
    damage = before["damage"]
    assert damage["financial_accounts_at_risk"][0]["service"] == "HDFC Bank"
    assert any(d["type"] == "Location history" for d in damage["data_exposed"])
    assert all(s["explanation"].startswith("The attacker") for s in before["steps"])

    after = res["after"]
    assert res["fixes_applied"]
    assert after["damage"]["accounts_reachable"] < damage["accounts_reachable"]
    assert res["improvement"]["accounts_reachable"] > 0
    assert res["previous_run"] is None

    again = client.post("/api/attack-sim/run", headers=headers, json={"entry_account_id": ids["gmail"]}).json()
    assert again["previous_run"]["accounts_reachable"] == damage["accounts_reachable"]
    assert len(client.get("/api/attack-sim/history", headers=headers).json()) == 2


def test_real_fixes_shrink_the_next_run(client, auth):
    headers, email = auth
    ids = network(client, headers, email)
    first = client.post("/api/attack-sim/run", headers=headers, json={"entry_account_id": ids["gmail"]}).json()

    # The user turns on 2FA on the bank and stops reusing the Instagram password.
    client.put(f"/api/accounts/{ids['bank']}", headers=headers, json={"has_2fa": True, "twofa_method": "totp"})
    client.put(f"/api/accounts/{ids['insta']}", headers=headers, json={"password_group": ""})

    second = client.post("/api/attack-sim/run", headers=headers, json={"entry_account_id": ids["gmail"]}).json()
    assert second["previous_run"]["accounts_reachable"] == first["before"]["damage"]["accounts_reachable"]
    assert second["before"]["damage"]["accounts_reachable"] < first["before"]["damage"]["accounts_reachable"]
    assert not second["before"]["damage"]["financial_accounts_at_risk"]


def test_other_users_accounts_are_off_limits(client, auth):
    headers, _ = auth
    assert client.post("/api/attack-sim/run", headers=headers, json={"entry_account_id": 999999}).status_code == 404


def test_sample_network_tells_the_full_story(client, auth):
    headers, _ = auth
    points = client.get("/api/attack-sim/demo/entry-points", headers=headers).json()
    assert points["demo"] and len(points["entry_points"]) == 12
    res = client.post("/api/attack-sim/demo/run", headers=headers, json={"entry_account_id": 11}).json()
    d = res["before"]["damage"]
    assert d["accounts_reachable"] >= 8 and d["financial_accounts_at_risk"]
    assert d["time_to_full_takeover_minutes"] < 15 and d["consequences"]
    elapsed = [s["elapsed_minutes"] for s in res["before"]["steps"]]
    assert elapsed == sorted(elapsed)
    assert any(b["to"] == "GitHub" for b in res["before"]["blocked"])
    assert res["after"]["damage"]["accounts_reachable"] < d["accounts_reachable"]
    # The sample never touches real data.
    assert client.get("/api/accounts/", headers=headers).json() in ([], {"items": []})
