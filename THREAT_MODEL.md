# Threat model

## Protected data

Authentication tokens, account inventory and relationships, email addresses, breach matches, permission notes, and locally imported password-reuse group labels.

## Trust boundaries

- The mobile client to API boundary carries account metadata and authentication tokens.
- External breach providers receive email addresses used for lookups. The user must control that address; ownership verification is a known gap.
- Policy pages and imported metadata are untrusted. Policy text is bounded, prompt-labeled as untrusted, and must not direct the model.
- Android Keystore and iOS Keychain hold mobile access tokens. The backend database stores user/account metadata and password hashes; it must never receive plaintext account passwords, TOTP secrets, or OAuth tokens.

## Controls in this implementation

- Token encryption on Android (AES-GCM key in Android Keystore) and device-only iOS Keychain items.
- A transient API failure does not erase a saved login; 401/403 responses do.
- Account APIs scope rows by authenticated user. Fix preview and completion also scope their records by user.
- Policy fetch allows HTTP(S) only, rejects credentials/local/private/link-local addresses, revalidates redirects, limits redirects and response size.
- Fixture and mock results are labeled; unknown account attributes remain unknown.

## Remaining risks

- OAuth email ownership verification and a complete Gmail OAuth integration are not implemented.
- DNS rebinding is not eliminated without a controlled egress proxy or IP-pinned transport.
- API deployment must use HTTPS/WSS and a persistent secret key; this repository's local development configuration is not production hardening.
- Push provider credentials and delivery semantics are not configured.
