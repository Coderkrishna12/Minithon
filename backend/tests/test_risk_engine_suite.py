import time
import pytest
from app.services.risk_engine import score_network, _blast


def test_unit_components_normalized():
    """Verify each component is bounded in 0..100."""
    account = {
        "id": 1,
        "category": "finance",
        "has_2fa": False,
        "twofa_method": None,
        "permissions": ["camera", "microphone", "sms", "location"],
        "password_group": "group_a",
        "breach_count": 5,
    }
    scores, components, privacy = score_network([account], [])
    c = components[1]
    assert 0 <= c["breach"] <= 100
    assert 0 <= c["permission_scope"] <= 100
    assert 0 <= c["password_reuse"] <= 100
    assert 0 <= c["missing_2fa"] <= 100
    assert 0 <= c["cascading_impact"] <= 100
    assert 0 <= scores[1] <= 100
    assert 0 <= privacy <= 100


def test_golden_fixture_gmail_recovers_10_accounts_is_critical():
    """Gmail with 2FA that recovers 10 accounts must receive a Critical score (>= 75)."""
    gmail = {
        "id": 1,
        "service_name": "Gmail",
        "category": "email",
        "has_2fa": True,
        "twofa_method": "totp",
        "permissions": [],
        "password_group": None,
        "breach_count": 0,
    }
    recovered = [
        {
            "id": i,
            "service_name": f"Service {i}",
            "category": "finance" if i % 2 == 0 else "social",
            "has_2fa": False,
            "twofa_method": None,
            "permissions": [],
            "password_group": None,
            "breach_count": 0,
        }
        for i in range(2, 12)
    ]
    accounts = [gmail] + recovered
    edges = [{"from_account_id": 1, "to_account_id": i, "connection_type": "recovery_email"} for i in range(2, 12)]

    scores, components, _ = score_network(accounts, edges)
    gmail_comp = components[1]
    assert gmail_comp["keystone"] is True
    assert gmail_comp["reachable_accounts"] == 10
    # Must be Critical (>= 75)
    assert scores[1] >= 75.0


def test_property_scores_in_range():
    """Property test: All scores are within 0..100 for arbitrary configurations."""
    accounts = [
        {"id": 1, "category": "finance", "has_2fa": True, "twofa_method": "passkey", "permissions": ["sms"], "breach_count": 2},
        {"id": 2, "category": "email", "has_2fa": False, "twofa_method": None, "permissions": ["contacts"], "breach_count": 0},
        {"id": 3, "category": "cloud", "has_2fa": None, "twofa_method": None, "permissions": [], "breach_count": 10},
    ]
    edges = [
        {"from_account_id": 2, "to_account_id": 1, "connection_type": "recovery_email"},
        {"from_account_id": 2, "to_account_id": 3, "connection_type": "sso"},
    ]
    scores, components, net_score = score_network(accounts, edges)
    assert 0 <= net_score <= 100
    for aid, s in scores.items():
        assert 0.0 <= s <= 100.0


def test_property_protective_control_never_raises_risk():
    """Adding 2FA or removing permissions never increases risk score."""
    base_acc = {"id": 1, "category": "cloud", "has_2fa": False, "permissions": ["camera", "microphone"], "breach_count": 1}
    scores_before, _, net_before = score_network([base_acc], [])

    # Adding 2FA
    protected_acc = dict(base_acc, has_2fa=True, twofa_method="totp")
    scores_after, _, net_after = score_network([protected_acc], [])
    assert scores_after[1] <= scores_before[1]
    assert net_after >= net_before

    # Removing permissions
    no_perm_acc = dict(protected_acc, permissions=[])
    scores_after_perm, _, net_after_perm = score_network([no_perm_acc], [])
    assert scores_after_perm[1] <= scores_after[1]
    assert net_after_perm >= net_after


def test_property_removing_edge_never_raises_blast_radius():
    """Removing an edge never raises blast radius."""
    accounts = [
        {"id": 1, "category": "email"},
        {"id": 2, "category": "finance"},
        {"id": 3, "category": "social"},
    ]
    edges_full = [
        {"from_account_id": 1, "to_account_id": 2, "connection_type": "recovery_email"},
        {"from_account_id": 1, "to_account_id": 3, "connection_type": "sso"},
    ]
    edges_reduced = [
        {"from_account_id": 1, "to_account_id": 2, "connection_type": "recovery_email"},
    ]
    scores_full, _, _ = _blast(accounts, edges_full)
    scores_reduced, _, _ = _blast(accounts, edges_reduced)
    assert scores_reduced[1] <= scores_full[1]


def test_determinism():
    """Identical inputs produce identical outputs across multiple calls."""
    accounts = [
        {"id": i, "category": "cloud" if i % 2 == 0 else "finance", "has_2fa": i % 3 == 0, "permissions": ["storage"] if i % 4 == 0 else []}
        for i in range(1, 20)
    ]
    edges = [{"from_account_id": 1, "to_account_id": i, "connection_type": "sso"} for i in range(2, 8)]

    r1 = score_network(accounts, edges)
    r2 = score_network(accounts, edges)
    assert r1 == r2


def test_performance_500_accounts():
    """500 accounts and 3,000 edges must execute under 2 seconds."""
    import random
    rng = random.Random(42)
    accounts = [
        {
            "id": i,
            "category": rng.choice(["finance", "email", "cloud", "social", "other"]),
            "has_2fa": rng.choice([True, False, None]),
            "twofa_method": rng.choice(["totp", "sms", "hardware", None]),
            "permissions": rng.sample(["camera", "microphone", "sms", "location", "contacts"], k=rng.randint(0, 3)),
            "password_group": f"group_{rng.randint(1, 20)}" if rng.random() > 0.5 else None,
            "breach_count": rng.randint(0, 3),
        }
        for i in range(1, 501)
    ]
    edges = []
    types = ["recovery_email", "sso", "password_reuse", "device_trust", "data_sharing"]
    for _ in range(3000):
        src = rng.randint(1, 500)
        tgt = rng.randint(1, 500)
        if src != tgt:
            edges.append({"from_account_id": src, "to_account_id": tgt, "connection_type": rng.choice(types)})

    start = time.perf_counter()
    scores, components, privacy = score_network(accounts, edges)
    elapsed = time.perf_counter() - start

    assert elapsed < 2.0, f"Expected < 2.0s, got {elapsed:.2f}s"
    assert len(scores) == 500
    assert 0 <= privacy <= 100
