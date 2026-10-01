# Deterministic risk model (`deterministic-2`)

The model is deterministic and explainable, not trained AI. Account components are bounded to 0–100:

- breach exposure: recent breach records weigh more; records exposing passwords/tokens weigh more;
- permission scope: sum of documented weights for known sensitive permissions;
- password reuse: logarithmic penalty based on accounts in the same reuse group;
- missing 2FA: unknown is scored as an uncertainty midpoint, not as “disabled”; SMS is weaker than TOTP, hardware keys, or passkeys;
- cascade impact: directed weighted reachability over recovery, SSO, password-reuse, device-trust, and data-sharing edges, with probability decay per hop.

Base account risk is `0.30*breach + 0.20*permission + 0.20*reuse + 0.15*missing_2fa + 0.15*cascade`. Accounts reaching at least five other tracked nodes are keystones and have a floor of 60 when 2FA is confirmed, otherwise 75. Network score is 100 minus asset- and cascade-weighted account risk, with a five-point penalty for each unmitigated keystone. Account asset weights are finance 1.0, email 0.9, cloud 0.7, social 0.5, other/unknown 0.3.

Fix previews clone the current tracked graph, simulate one modeled change, and recompute this same formula. Score values are estimates from recorded data, not a measurement of the external service. A user must make the change externally and then confirm it in the app. Data completeness and provider provenance limit accuracy; unknown relationships are omitted.
