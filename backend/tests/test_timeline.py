def test_timeline_survives_completed_fixes_and_tracks_score(client, auth):
    headers, email = auth
    client.post("/api/accounts/", headers=headers, json={
        "service_name": "Gmail", "category": "email", "email_used": email, "has_2fa": False, "password_group": "a"})
    client.post("/api/accounts/", headers=headers, json={
        "service_name": "PayPal", "category": "finance", "email_used": email, "has_2fa": False, "password_group": "a"})

    history = client.get("/api/timeline/score-history", headers=headers).json()
    assert len(history) == 1 and history[0]["event_type"] == "baseline"

    fixes = client.get("/api/dashboard/fixes", headers=headers).json()
    assert client.patch(f"/api/dashboard/fixes/{fixes[0]['id']}/complete", headers=headers).status_code == 200
    client.get("/api/dashboard/", headers=headers)

    res = client.get("/api/timeline/events", headers=headers)
    assert res.status_code == 200, res.text
    kinds = {e["type"] for e in res.json()}
    assert {"account_added", "fix_completed", "score_change"} <= kinds
    assert all(e["date"] for e in res.json())
    # The fix shows once, not again as an audit entry.
    assert sum(1 for e in res.json() if "enable_2fa" in e["title"] or e["type"] == "fix_completed") == 1

    scores = [h["privacy_score"] for h in client.get("/api/timeline/score-history", headers=headers).json()]
    assert len(scores) >= 2 and scores[-1] > scores[0]
