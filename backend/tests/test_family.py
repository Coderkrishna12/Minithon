import secrets

from tests.test_real_data import handler_for, xon_analytics


def register(client, name):
    email = f"{name}{secrets.token_hex(3)}@example.com"
    credential = secrets.token_urlsafe(16)
    client.post("/api/auth/register", json={
        "email": email, "username": email.split("@")[0], "password": credential, "full_name": name.title(),
    })
    token = client.post("/api/auth/login", json={"email": email, "password": credential}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}, email


def add(client, headers, **account):
    return client.post("/api/accounts/", headers=headers, json=account).json()


def test_owner_sees_invite_code_and_member_can_join_with_messy_input(client):
    owner, _ = register(client, "mum")
    kid, _ = register(client, "kid")

    group = client.post("/api/family/groups", headers=owner, json={"name": "Home", "type": "family"}).json()
    code = group["invite_code"]
    assert len(code) == 8 and group["member_count"] == 1 and group["my_role"] == "owner"

    messy = f"  {code[:4].lower()}-{code[4:].lower()} "
    joined = client.post("/api/family/join", headers=kid, json={"invite_code": messy})
    assert joined.status_code == 200
    assert joined.json()["group"]["invite_code"] is None  # members don't get the code

    groups = client.get("/api/family/groups", headers=owner).json()
    assert groups[0]["member_count"] == 2
    again = client.post("/api/family/join", headers=kid, json={"invite_code": code})
    assert again.status_code == 400

    notes = client.get("/api/notifications/", headers=owner).json()
    assert any("joined Home" in n["title"] for n in notes)


def test_dashboard_respects_sharing_and_finds_shared_breached_services(client):
    owner, _ = register(client, "mum")
    kid, _ = register(client, "kid")
    gid = client.post("/api/family/groups", headers=owner, json={"name": "Home"}).json()["id"]
    code = client.get("/api/family/groups", headers=owner).json()[0]["invite_code"]
    client.post("/api/family/join", headers=kid, json={"invite_code": code})

    add(client, owner, service_name="Gmail", category="email", has_2fa=True)
    add(client, owner, service_name="Netflix", category="entertainment", has_2fa=False)
    add(client, kid, service_name="Gmail", category="email", has_2fa=False, password_group="pw1")
    add(client, kid, service_name="Netflix", category="entertainment", has_2fa=False, password_group="pw1")

    dash = client.get(f"/api/family/dashboard/{gid}", headers=owner).json()
    kid_row = next(m for m in dash["members"] if not m["is_me"])
    assert kid_row["share_level"] == "summary"
    assert kid_row["total_accounts"] == 2 and kid_row["email_without_2fa"] == 1
    assert kid_row["top_issues"] == []  # summary sharing hides account names
    assert dash["shared_risks"] == []  # only the owner's services are visible
    assert any(r["topic"] == "enable_2fa" and r["member_user_id"] == kid_row["user_id"] for r in dash["recommendations"])

    client.patch(f"/api/family/groups/{gid}/sharing", headers=kid, json={"share_level": "detailed"})
    dash = client.get(f"/api/family/dashboard/{gid}", headers=owner).json()
    kid_row = next(m for m in dash["members"] if not m["is_me"])
    assert kid_row["top_issues"], "detailed sharing shows risky accounts"
    assert {s["service"] for s in dash["shared_risks"]} == {"Gmail", "Netflix"}


def test_roles_nudges_and_permissions(client):
    owner, _ = register(client, "mum")
    dad, _ = register(client, "dad")
    kid, _ = register(client, "kid")
    gid = client.post("/api/family/groups", headers=owner, json={"name": "Home"}).json()["id"]
    code = client.get("/api/family/groups", headers=owner).json()[0]["invite_code"]
    client.post("/api/family/join", headers=dad, json={"invite_code": code})
    client.post("/api/family/join", headers=kid, json={"invite_code": code})
    ids = {m["display_name"]: m["user_id"] for m in client.get(f"/api/family/dashboard/{gid}", headers=owner).json()["members"]}

    # Members can't nudge or see the code; promoting to guardian grants both.
    assert client.post(f"/api/family/groups/{gid}/nudge", headers=dad,
                       json={"member_user_id": ids["Kid"], "topic": "enable_2fa"}).status_code == 403
    assert client.patch(f"/api/family/groups/{gid}/members/{ids['Dad']}", headers=kid, json={"role": "guardian"}).status_code == 403
    assert client.patch(f"/api/family/groups/{gid}/members/{ids['Dad']}", headers=owner, json={"role": "guardian"}).status_code == 200
    assert client.get("/api/family/groups", headers=dad).json()[0]["invite_code"] == code

    sent = client.post(f"/api/family/groups/{gid}/nudge", headers=dad, json={"member_user_id": ids["Kid"], "topic": "enable_2fa"})
    assert sent.status_code == 200
    assert any("Turn on two-factor" in n["title"] for n in client.get("/api/notifications/", headers=kid).json())

    new_code = client.post(f"/api/family/groups/{gid}/invite-code", headers=dad).json()["invite_code"]
    assert new_code != code
    assert client.post(f"/api/family/groups/{gid}/invite-code", headers=kid).status_code == 403

    assert client.delete(f"/api/family/groups/{gid}/members/{ids['Kid']}", headers=owner).status_code == 200
    assert client.get(f"/api/family/dashboard/{gid}", headers=kid).status_code == 404


def test_owner_leaving_hands_over_to_guardian(client):
    owner, _ = register(client, "mum")
    dad, _ = register(client, "dad")
    gid = client.post("/api/family/groups", headers=owner, json={"name": "Home"}).json()["id"]
    code = client.get("/api/family/groups", headers=owner).json()[0]["invite_code"]
    client.post("/api/family/join", headers=dad, json={"invite_code": code})

    assert client.post(f"/api/family/groups/{gid}/leave", headers=owner).json()["status"] == "left"
    groups = client.get("/api/family/groups", headers=dad).json()
    assert groups[0]["my_role"] == "owner" and groups[0]["invite_code"]
    assert client.post(f"/api/family/groups/{gid}/leave", headers=dad).json()["status"] == "deleted"
    assert client.get("/api/family/groups", headers=dad).json() == []


def test_guardians_are_alerted_when_a_member_is_breached(client, mock_http):
    owner, _ = register(client, "mum")
    kid, kid_email = register(client, "kid")
    gid = client.post("/api/family/groups", headers=owner, json={"name": "Home"}).json()["id"]
    code = client.get("/api/family/groups", headers=owner).json()[0]["invite_code"]
    client.post("/api/family/join", headers=kid, json={"invite_code": code, "share_level": "detailed"})

    add(client, kid, service_name="Adobe", service_url="adobe.com", email_used=kid_email)
    mock_http["handler"] = handler_for(xon_analytics([
        {"breach": "Adobe", "domain": "adobe.com", "xposed_date": "2013", "xposed_data": "Email addresses;Passwords"},
    ]), only_email=kid_email)
    client.post("/api/breaches/scan-all", headers=kid)

    alerts = [n for n in client.get("/api/notifications/", headers=owner).json() if "Family Shield" in n["title"]]
    assert alerts and "Adobe" in alerts[0]["message"]
    dash = client.get(f"/api/family/dashboard/{gid}", headers=owner).json()
    assert any(a["kind"] == "breach" and "Adobe" in a["text"] for a in dash["activity"])
    assert dash["summary"]["breached_accounts"] == 1
