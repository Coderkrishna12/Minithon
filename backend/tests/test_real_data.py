import httpx

CATALOG = [
    {"Name": "Adobe", "Title": "Adobe", "Domain": "adobe.com", "BreachDate": "2013-10-04", "PwnCount": 152445165,
     "DataClasses": ["Email addresses", "Password hints", "Passwords", "Usernames"]},
    {"Name": "LinkedIn", "Title": "LinkedIn", "Domain": "linkedin.com", "BreachDate": "2012-05-05", "PwnCount": 164611595,
     "DataClasses": ["Email addresses", "Passwords"]},
    {"Name": "FakeDump", "Title": "Fake Dump", "Domain": "", "BreachDate": "2020-01-01", "PwnCount": 1,
     "DataClasses": [], "IsFabricated": True},
]


def xon_analytics(email_breaches: list[dict], pastes: int = 0) -> dict:
    return {
        "ExposedBreaches": {"breaches_details": email_breaches} if email_breaches else None,
        "PastesSummary": {"cnt": pastes, "domain": "", "tmpstmp": ""},
    }


def handler_for(analytics: dict, only_email: str | None = None):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "haveibeenpwned.com" and request.url.path.endswith("/breaches"):
            return httpx.Response(200, json=CATALOG)
        if request.url.host == "api.xposedornot.com" and request.url.path.endswith("/breach-analytics"):
            if only_email and request.url.params.get("email") != only_email:
                return httpx.Response(404, json={"Error": "Not found"})
            return httpx.Response(200, json=analytics)
        return httpx.Response(404)
    return handler


def add(client, headers, **account):
    r = client.post("/api/accounts/", headers=headers, json=account)
    assert r.status_code == 201, r.text
    return r.json()


def test_scan_uses_real_sources_and_flags_unlisted_breaches(client, auth, mock_http):
    headers, email = auth
    add(client, headers, service_name="Adobe", service_url="https://www.adobe.com", email_used=email, category="productivity")
    add(client, headers, service_name="LinkedIn", service_url="linkedin.com", email_used="other@example.com", category="work")
    mock_http["handler"] = handler_for(xon_analytics([
        {"breach": "Adobe", "domain": "adobe.com", "xposed_date": "2013", "xposed_data": "Email addresses;Passwords"},
        {"breach": "Canva", "domain": "canva.com", "xposed_date": "2019", "xposed_data": "Email addresses;Names"},
    ]), only_email=email)

    result = client.post("/api/breaches/scan-all", headers=headers).json()

    assert result["errors"] == []
    assert result["sources"] == {"catalog": "hibp", "email": "xposedornot"}
    assert result["confirmed_account_breaches"] == 1
    assert [u["name"] for u in result["unlisted_exposures"]] == ["Canva"]

    history = {h["breach_name"]: h for h in client.get("/api/breaches/history", headers=headers).json()}
    assert history["Adobe"]["source"] == "xposedornot"
    assert history["LinkedIn"]["source"] == "hibp_catalog"
    assert "Fake Dump" not in history


def test_scan_reports_unreachable_sources_instead_of_inventing_data(client, auth, mock_http):
    headers, email = auth
    add(client, headers, service_name="Adobe", service_url="adobe.com", email_used=email)

    def offline(request):
        raise httpx.ConnectError("blocked", request=request)
    mock_http["handler"] = offline

    result = client.post("/api/breaches/scan-all", headers=headers).json()

    assert result["total_breaches_found"] == 0
    assert len(result["errors"]) == 2
    assert client.get("/api/breaches/history", headers=headers).json() == []


def test_dark_web_alerts_come_only_from_real_exposures(client, auth, mock_http):
    headers, email = auth
    add(client, headers, service_name="Adobe", service_url="adobe.com", email_used=email)

    mock_http["handler"] = handler_for(xon_analytics([]))
    assert client.post("/api/darkweb/scan", headers=headers).json()["total_alerts"] == 0

    mock_http["handler"] = handler_for(xon_analytics(
        [{"breach": "Adobe", "domain": "adobe.com", "xposed_date": "2013", "xposed_data": "Email addresses;Passwords"}],
        pastes=2,
    ))
    alerts = client.post("/api/darkweb/scan", headers=headers).json()["alerts"]
    assert sorted(a["source_type"] for a in alerts) == ["credential_dump", "data_paste"]


def test_graph_connections_are_derived_from_account_data(client, auth, mock_http):
    headers, email = auth
    gmail = add(client, headers, service_name="Gmail", service_url="gmail.com", email_used=email, category="email")
    spotify = add(client, headers, service_name="Spotify", service_url="spotify.com", email_used=email, login_method="google_sso", password_group="A")
    dropbox = add(client, headers, service_name="Dropbox", service_url="dropbox.com", email_used="x@example.org", password_group="A")

    edges = {(e["source"], e["target"], e["type"]) for e in client.get("/api/graph/", headers=headers).json()["edges"]}

    assert (str(gmail["id"]), str(spotify["id"]), "sso") in edges
    assert (str(gmail["id"]), str(spotify["id"]), "recovery_email") in edges
    assert (str(spotify["id"]), str(dropbox["id"]), "password_reuse") in edges

    attack = client.post(f"/api/graph/simulate-attack?entry_account_id={gmail['id']}", headers=headers).json()
    assert attack["totalCompromised"] == 3


def test_import_discovers_services_from_email_domains(client, auth, mock_http):
    headers, _ = auth
    mock_http["handler"] = handler_for(xon_analytics([]))
    body = "From: no-reply@mail.adobe.com\nVisit https://www.notion.so/login\nSent via sendgrid.net"

    found = {d["service_url"]: d for d in client.post("/api/import/scan-email", headers=headers, json={"email_content": body}).json()["discovered"]}

    assert set(found) == {"adobe.com", "notion.so"}
    assert found["adobe.com"]["breached"] is True
    assert found["notion.so"]["breached"] is False


def test_chat_without_key_explains_instead_of_faking_answers(client, auth):
    headers, _ = auth
    r = client.post("/api/ai/chat", headers=headers, json={"message": "What is my biggest risk?"})
    assert r.status_code == 503
    assert "ANTHROPIC_API_KEY" in r.json()["detail"]
