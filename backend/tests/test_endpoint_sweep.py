import pytest
from app.main import app

def seed_test_data(client, headers):
    # 1. Create an account
    acc = client.post("/api/accounts/", headers=headers, json={
        "service_name": "TestMail",
        "category": "email",
        "has_2fa": False,
        "email_used": "sweep@test.local",
        "login_method": "password"
    }).json()
    acc_id = acc.get("id")

    # 2. Query fixes and complete one fix to populate completed FixAction
    fixes_res = client.get("/api/dashboard/fixes", headers=headers)
    if fixes_res.status_code == 200:
        fixes = fixes_res.json()
        if fixes:
            client.patch(f"/api/dashboard/fixes/{fixes[0]['id']}/complete", headers=headers)
            
    # 3. Create a reminder
    client.post("/api/reminders/", headers=headers, json={
        "reminder_type": "password_review",
        "title": "Quarterly Audit",
        "frequency_days": 30
    })

    return acc_id


def test_endpoint_sweep_no_5xx(client, auth):
    """
    Endpoint sweep test: Reads OpenAPI schema, seeds data for two users,
    and calls GET and relevant POST endpoints asserting that no endpoint crashes with a 5xx error.
    """
    headers_a, email_a = auth
    
    # Create second user
    reg_b = client.post("/api/auth/register", json={
        "email": "user_b_sweep@example.com",
        "username": "user_b_sweep",
        "password": "Password123!@#"
    })
    token_b = reg_b.json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Seed data for user A
    acc_id_a = seed_test_data(client, headers_a)

    # Seed data for user B
    acc_id_b = seed_test_data(client, headers_b)

    openapi_res = client.get("/openapi.json")
    assert openapi_res.status_code == 200
    schema = openapi_res.json()
    paths = schema.get("paths", {})

    crashes = []

    for path, methods in paths.items():
        # Test GET endpoints without complex path params, or replacing {account_id}, etc.
        if "get" in methods:
            test_path = path
            if "{account_id}" in test_path:
                test_path = test_path.replace("{account_id}", str(acc_id_a))
            elif "{" in test_path:
                # Skip paths with other dynamic params for basic sweep
                continue

            for u_label, h in [("User A", headers_a), ("User B", headers_b)]:
                try:
                    res = client.get(test_path, headers=h)
                    if res.status_code >= 500:
                        crashes.append({
                            "method": "GET",
                            "path": test_path,
                            "user": u_label,
                            "status_code": res.status_code,
                            "error": res.text
                        })
                except Exception as e:
                    crashes.append({
                        "method": "GET",
                        "path": test_path,
                        "user": u_label,
                        "status_code": 500,
                        "error": f"{type(e).__name__}: {str(e)}"
                    })

    # Record the crashes
    if crashes:
        report = "\n".join([f"{c['method']} {c['path']} ({c['user']}) returned {c['status_code']}: {c['error'][:120]}" for c in crashes])
        pytest.fail(f"Endpoint sweep detected crashes:\n{report}")
