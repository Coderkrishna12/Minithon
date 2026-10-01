# Deterministic risk model (`deterministic-2`)

The model is deterministic and explainable, not trained AI. Account components are bounded to 0–100:

- breach exposure: recent breach records weigh more; records exposing passwords/tokens weigh more;
- permission scope: sum of documented weights for known sensitive permissions;
- password reuse: logarithmic penalty based on accounts in the same reuse group;
- missing 2FA: unknown is scored as an uncertainty midpoint (50), not as “disabled”; SMS (60) is weaker than TOTP (20), hardware keys (0), or passkeys (0);
- cascade impact (blast radius): directed weighted reachability over recovery_email (0.90), recovery_phone (0.90), SSO (0.85), password_reuse (0.80), device_trust (0.50), and data_sharing (0.30) edges, with per-hop probability decay of 0.9. Target accounts are weighted by asset value: finance 1.0, email 0.9, cloud 0.7, social 0.5, other/unknown 0.3. Normalized radius is computed against maximum possible reachable assets.

Base account risk is `0.30*breach + 0.20*permission + 0.20*reuse + 0.15*missing_2fa + 0.15*cascade`.
Accounts in the top decile of blast radius reaching at least 5 other nodes are keystones:
- Reaching >= 10 accounts establishes a massive keystone with a floor of 75 (Critical) even with 2FA;
- Reaching >= 5 accounts with verified strong 2FA (passkey/hardware/TOTP) lowers the floor to 60 (High);
- Unmitigated keystones (missing or weak 2FA) have a risk floor of 75 (Critical).

Network privacy score is 100 minus asset- and cascade-weighted account risk, with a five-point penalty for each unmitigated keystone (bounded to 0..100).

Fix previews clone the current tracked graph, simulate one modeled change, and recompute this same formula. Score values are estimates from recorded data, not a measurement of the external service. A user must make the change externally and then confirm it in the app. Data completeness and provider provenance limit accuracy; unknown relationships are omitted.

