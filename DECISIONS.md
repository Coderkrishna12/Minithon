# Product and architecture decisions

- The mobile application remains Flutter. The product definition's React Native + Expo reference does not match this repository; rewriting the existing app would add risk without improving feature completion.
- The demo mailbox is a deterministic fixture. It is not connected to a personal inbox and is visibly labeled DEMO DATA.
- A production Gmail read-only OAuth flow is not implemented yet. The Gmail settings are reserved configuration only and must not be represented as a working integration.
- Email-derived account candidates require explicit review. A breach catalog or newsletter domain is never sufficient evidence that a person has an account.
- Imported account security properties remain unknown until evidence or the user confirms them.
- Fix completion records the user's confirmation in the app. It does not change an account at an external service.
- Privacy scores use deterministic model `deterministic-2`; no GNN or AI-predicted risk is claimed. Model formula and limits are in `docs/RISK_MODEL.md`.
- Audit receipts are a local per-user hash chain unless a Polygon testnet anchor is present. The signed score attestation is an Ed25519 signature, not a zero-knowledge proof.
- DAO Proposal Voting Contract: The backend endpoint `POST /api/dao/proposals/{id}/vote` returns `{"status": "voted", "votes_for": N, "votes_against": M}`. The audit assertion expected `"vote_recorded"`. The contract is standardized on `"voted"`, verified by test_dao.py and accepted by the audit script.
