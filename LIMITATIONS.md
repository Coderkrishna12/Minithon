# Known limitations

This repository now has useful end-to-end demo flows, but it is not a production-ready privacy platform.

- Gmail OAuth and real inbox scanning are not implemented. Use the visibly labeled fixture mailbox or review accounts manually. Do not paste real inbox content into the legacy `/api/import/scan-email` endpoint.
- Password-manager CSV import and a demonstrated no-plaintext network assertion are not implemented. No password is required by the fixture import.
- The fixture scan is deterministic demo data and does not describe the signed-in user's real accounts or exposure.
- HIBP catalog and XposedOrNot calls depend on network availability and provider rules. Email ownership verification before breach lookup is not implemented; avoid querying other people's email addresses.
- Push notifications (FCM/APNs), scheduled delivery guarantees, and reconnect backoff are incomplete. The app's foreground WebSocket is not background push.
- Account changes are not performed automatically. A fix is recorded only after user confirmation and its risk model values represent modeled state.
- iOS cannot enumerate other installed apps' permissions. Android visibility is limited by OS package-visibility policy.
- Privacy policy scoring is a heuristic or configured Claude response, not a legal assessment. Public page fetching is constrained but not a substitute for a hardened egress proxy.
- DAO, NFT, family-sharing, AR, and data-broker features are demos or partial flows; they are not legal certification or guaranteed removal.
- Public receipt verification of arbitrary users' receipts is not implemented. The authenticated per-user chain verifies only that user's local audit history.
- Non-mobile development targets retain the existing SharedPreferences token fallback; Android uses Keystore encryption and iOS uses device-only Keychain storage.
