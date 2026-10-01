from tests.test_real_data import CATALOG, handler_for, xon_analytics


def test_exposure_profile_explains_what_leaked_and_stores_nothing(client, auth, mock_http):
    headers, _ = auth
    target = "someone@example.com"
    mock_http["handler"] = handler_for(xon_analytics([
        {"breach": "Adobe", "domain": "adobe.com", "xposed_date": "2013", "xposed_data": "Email addresses;Passwords;Usernames"},
        {"breach": "LinkedIn", "domain": "linkedin.com", "xposed_date": "2012", "xposed_data": "Email addresses;Passwords"},
        {"breach": "ShopX", "domain": "shopx.example", "xposed_date": "2021",
         "xposed_data": "Email addresses;Phone numbers;Physical addresses;Partial credit card data"},
    ], pastes=2), only_email=target)

    assert client.post("/api/exposure/scan", headers=headers, json={"email": target}).status_code == 400
    res = client.post("/api/exposure/scan", headers=headers, json={"email": target, "consent": True})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["summary"]["breaches"] == 3 and body["summary"]["password_breaches"] == 2
    assert body["summary"]["first_year"] == 2012 and body["level"] == "critical"
    assert {e["key"] for e in body["exposed"]} >= {"passwords", "contact", "financial", "social"}
    assert any(a["title"] == "Credential stuffing" for a in body["attacks"])
    adobe = next(b for b in body["breaches"] if b["name"] == "Adobe")
    assert adobe["date"] == "2013-10-04" and adobe["records"] == CATALOG[0]["PwnCount"]
    assert body["stored"] is False
    assert client.get("/api/accounts/", headers=headers).json() == []

    assert client.post("/api/exposure/scan", headers=headers, json={"email": "nope", "consent": True}).status_code == 422
