import pytest


def test_fix_preview_delta_equals_actual_delta_for_all_fix_types(client, auth):
    headers, _ = auth

    # 1. Create a cluster of accounts with password reuse, missing 2fa, and unnecessary permissions
    resp_acc1 = client.post("/api/accounts/", headers=headers, json={
        "service_name": "Account Primary",
        "category": "email",
        "has_2fa": False,
        "password_group": "reuse_cluster_1",
        "permissions": ["camera", "sms"],
    })
    acc1_id = resp_acc1.json()["id"]

    resp_acc2 = client.post("/api/accounts/", headers=headers, json={
        "service_name": "Account Linked",
        "category": "finance",
        "has_2fa": False,
        "password_group": "reuse_cluster_1",
        "permissions": ["location"],
    })
    acc2_id = resp_acc2.json()["id"]

    # Connect them via password reuse
    client.post("/api/connections/", headers=headers, json={
        "from_account_id": acc1_id,
        "to_account_id": acc2_id,
        "connection_type": "password_reuse",
    })

    # Get initial dashboard state & fixes
    dash = client.get("/api/dashboard/", headers=headers).json()
    initial_score = dash["privacy_score"]
    fixes_resp = client.get("/api/dashboard/fixes", headers=headers)
    assert fixes_resp.status_code == 200
    fixes = fixes_resp.json()
    assert len(fixes) > 0

    # Test preview delta vs completed delta for each pending fix
    current_score = initial_score
    for fix in fixes:
        fix_id = fix["id"]
        # Preview the fix
        preview_resp = client.get(f"/api/dashboard/fixes/{fix_id}/preview", headers=headers)
        assert preview_resp.status_code == 200
        preview = preview_resp.json()
        expected_improvement = preview["score_improvement"]
        expected_after = preview["after_score"]

        # Complete the fix (PATCH)
        comp_resp = client.patch(f"/api/dashboard/fixes/{fix_id}/complete", headers=headers)
        assert comp_resp.status_code == 200

        # Check current score in dashboard
        new_dash = client.get("/api/dashboard/", headers=headers).json()
        actual_score = new_dash["privacy_score"]
        actual_delta = actual_score - current_score

        # The preview delta MUST equal exactly the delta after the user completes the fix!
        assert actual_score == expected_after, (
            f"Fix {fix['action_type']} on account {fix['account_id']}: "
            f"Expected after_score {expected_after}, got {actual_score}"
        )
        assert actual_delta == expected_improvement, (
            f"Fix {fix['action_type']} on account {fix['account_id']}: "
            f"Expected improvement {expected_improvement}, got {actual_delta}"
        )
        current_score = actual_score
