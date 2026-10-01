def test_device_apps_become_categorised_candidates(client, auth, mock_http):
    headers, _ = auth
    apps = [
        {"package": "com.instagram.android", "label": "Instagram"},
        {"package": "net.one97.paytm", "label": "Paytm"},
        {"package": "com.google.android.apps.photos", "label": "Photos"},
        {"package": "com.example.flashlight", "label": "Torch"},
    ]
    res = client.post("/api/import/device-apps", headers=headers, json={"apps": apps}).json()
    names = {d["service_name"]: d for d in res["discovered"]}
    assert set(names) == {"Instagram", "Paytm", "Google Photos"}
    assert names["Paytm"]["category"] == "finance" and res["discovered"][0]["service_name"] == "Paytm"
    assert names["Google Photos"]["login_method"] == "google_sso"

    client.post("/api/import/bulk-add", headers=headers, json={"services": ["Paytm", "Instagram"], "added_via": "device_apps"})
    accounts = {a["service_name"]: a for a in client.get("/api/accounts/", headers=headers).json()}
    assert accounts["Paytm"]["category"] == "finance" and accounts["Instagram"]["service_url"] == "instagram.com"
    again = client.post("/api/import/device-apps", headers=headers, json={"apps": apps}).json()
    assert {d["service_name"] for d in again["discovered"] if d["already_tracked"]} == {"Paytm", "Instagram"}


def test_password_csv_keeps_site_and_login_but_never_passwords(client, auth):
    headers, email = auth
    rows = [
        {"service_name": "Google", "url": "https://accounts.google.com", "username": email, "password_group": "g1"},
        {"service_name": "My Bank", "url": "https://netbanking.hdfcbank.com/login", "username": email},
        {"service_name": "Some Forum", "url": "https://forum.example.org", "username": "krish", "password_group": "g1"},
    ]
    res = client.post("/api/import/password-manager-csv", headers=headers, json={"services": rows})
    assert res.status_code == 200
    accounts = {a["service_name"]: a for a in client.get("/api/accounts/", headers=headers).json()}
    assert accounts["HDFC Bank"]["category"] == "finance" and accounts["HDFC Bank"]["email_used"] == email
    assert accounts["Some Forum"]["service_url"] == "example.org" and accounts["Some Forum"]["username_used"] == "krish"
    leaked = client.post("/api/import/password-manager-csv", headers=headers,
                         json={"services": [{"service_name": "X", "password": "hunter2"}]})
    assert leaked.status_code == 422
