## 3. PHASE PLAN WITH HARD GATES

Order is by **demo impact**. Do not start a phase until the previous gate is green. After each phase: commit, run all tests, re-run `/audit/run_audit.sh`, update `/audit/AUDIT_REPORT.md` and `VERIFICATION.md` with real outputs.

### PHASE 0: Baseline and safety net
- Create a branch `fix/audit-closure`. Run the full existing suite and the audit; save results as `/audit/baseline/`.
- Add the endpoint sweep test (Section 2.1) in "expected-failing" state to record current crashes.
- *Gate:* baseline recorded; CI runs.

### PHASE 1: Crashes and contract fixes
- Implement the datetime fix (Section 2.1) and the BC-4b contract fix (Section 2.2).
- *Gate:* `M4-d` and `M5-c` pass; endpoint sweep shows zero 5xx; `ruff DTZ` clean; BC-4b passes against the contract.

### PHASE 2: Truthful risk engine and the RISK GRAPH screen
First verify and, if needed, correct the engine:
- Component weights exactly per PDF: breach 30%, permission scope 20%, password reuse 20%, missing 2FA 15%, cascading impact 15%, each normalized to 0..100.
- **Cascade and keystone rule:** the 15% cascade weight alone cannot make a well-protected hub "Critical". Implement blast radius (per-hop decay 0.9, best-path probability, targets weighted by asset value: finance 1.0, email 0.9, cloud 0.7, social 0.5, other 0.3); if an account is in the top decile of blast radius **and** reaches ≥ 5 accounts, `final = max(base, 75)`; strong 2FA lowers but never below 60. Document in `docs/risk-model.md`.
- Network privacy score 0..100, deterministic, versioned.
- **Fix ranking:** each candidate fix is applied to a cloned graph and the engine re-run; rank by `scoreGain / estimatedMinutes`. The preview delta **must equal exactly** the delta after the user completes the fix.
- Tests: unit (every component), golden fixtures (Gmail with 2FA that recovers 10 accounts is Critical), property tests (scores in 0..100; adding a protective control never raises risk; removing an edge never raises blast radius), determinism, performance (500 accounts / 3,000 edges under 2 s).

**Build the Risk Graph screen** (`/graph`), driven by the **real inventory API** (not a hardcoded fixture):
1. Cytoscape.js force-directed graph (fcose). Node color by risk (green/amber/red/dark-red), size by blast radius, icon + label + a risk badge (✓ / ! / ‼). Never color-only.
2. Edge styles by type (reuse dashed, recovery solid, SSO, cloud/data dotted) with a legend and filter chips: All / Password reuse / Recovery / Sign-in links / Payments.
3. Hover or focus a node: highlight everything it can reach (blast radius), dim the rest.
4. Click a node: drawer with score ring, component breakdown, plain-English "Why this score?", attack paths reaching it, and its top 3 fixes with real before/after numbers.
5. Single Points of Failure banner (top 3 keystones, pulsing outline): "If this account falls, N others fall too."
6. **Fix Preview:** a ranked checklist; ticking a fix re-runs the engine and animates the recoloring and score gauge (before/after).
7. Heatmap mode, mini-map (`cytoscape-navigator`), zoom/pan/fullscreen, reset.
8. Accessibility: keyboard navigation (Tab through nodes, Enter opens drawer), sortable **table view** alternative, ARIA labels, `prefers-reduced-motion`.
9. Performance: 500 nodes ≥ 30 FPS (canvas renderer, label level-of-detail).
10. Empty state (no accounts yet), error state, loading skeleton. A "DEMO DATA" ribbon whenever seed data is shown.
- *Gate:* all engine tests pass; Playwright test: add accounts and links via UI → graph shows them → open the drawer → tick a fix → score changes by exactly the previewed amount; keyboard-only walkthrough passes; FPS target met.

### PHASE 3: Fix Checklist completion and Cascade Alerts
- **`M3-c` Deep Links:** build `services.json` (≥ 100 popular services) with `domains`, `category`, `securityUrl`, `twoFAUrl`, `passwordUrl`, `deleteUrl`, `passkeySupport`, `verifiedAt`. Fix cards open the correct page. Add `scripts/check-links.ts` (retry, follow redirects, flag dead links, treat login redirects as OK) and run it in CI weekly; a test asserts every catalog entry has the required fields and a valid URL.
- **`M3-d` Guided Walkthroughs:** structured step data (title, plain-language description, optional screenshot, expected result) for the top 20 services × (enable 2FA, change password, revoke permission, delete account), plus a generic fallback per fix type. Step-by-step UI with progress, "I did this" confirmation, and completion that feeds the fix tracker.
- Fix receipts: completing a fix creates a leaf for blockchain anchoring (Phase 5) and recalculates the score.
- **`M5-b` Cascade Alerts:** when a breach is recorded for account X (HIBP result, webhook, or manual trigger), run blast radius from X, create an alert listing downstream accounts with plain-English reasons, generate an **emergency checklist ordered by dependency** (secure the hub first), and push it over **WebSocket** and **Web Push** (VAPID + service worker). Deduplicate alerts; classify Critical/Warning/Info; quiet hours per user.
- *Gate:* Playwright: trigger a breach for a hub account → cascade alert with the correct downstream list appears over WebSocket within 5 s → emergency checklist shows hub first; dead-link check passes; walkthrough completion updates progress.

### PHASE 4: THE FAKE WEBSITE (PHISHING) DEMO SCREEN + REAL LINK CHECKER
**Part A: the real link/message checker** (`packages/link-check`, endpoint `POST /api/v1/link-check`):
```json
{ "verdict": "dangerous|suspicious|unknown|likely_safe", "score": 0-100,
  "reasons": [{ "id": "domain_age", "severity": "high", "text": "This website was created only 2 days ago." }],
  "advice": "Do not open this link. It is not safe.", "modes": { "rdap": "live|mock", "safeBrowsing": "live|mock" } }
```
Signals (plain-English reason for each; documented weights and thresholds in `docs/linkcheck.md`): lookalike domain (Damerau-Levenshtein, homoglyph normalization, brand + keyword patterns like `brand-kyc-update`, `secure-login`); risky TLD and URL structure (IP host, `@`, punycode, very long subdomains, URL shorteners); no HTTPS or credential form over HTTP; domain age (RDAP); Safe Browsing and community reports; optional page analysis (password/OTP fields, form action to a different domain) with strict **SSRF protection** (block private/loopback/link-local IPs after DNS resolution, 5 s timeout, 1 MB limit, no JS execution, max 3 redirects). `likely_safe` is never "safe"; thin evidence returns `unknown`. Also `POST /api/v1/message-check` (urgency, threats, KYC/refund lures, OTP/password requests; extracts links and checks each).

**Part B: the demo screen** (`/phishing`), a phone mockup beside a "criminal's laptop" terminal, large hint bar, simple language, text ≥ 18px:
- **Without protection:** scam SMS arrives (vibration + chime), "SafeTrust Bank: Your account will be BLOCKED today! Update your KYC immediately: …". The **viewer taps the link** → fake bank site with a red "Not secure" address bar → fake Customer ID, password and OTP auto-type → the **viewer taps "Update KYC"** → laptop shows "NEW VICTIM CAUGHT" with the details → it logs in to the bank and transfers money in two steps, the phone balance counts down with debit alerts, red flash and siren → finale "You were not hacked. You were **tricked**" with two plain rules (banks never ask for password/OTP in a message; never tap links about money).
- **With PrivacyShield:** same SMS with a red banner "This message looks like a SCAM. Do not tap the link." Tapping the link opens a full red screen: **"DANGEROUS WEBSITE BLOCKED. Do NOT open this. It is not safe."**, the **reasons returned by the real link-check engine**, and a big green "Take me to safety" button → safe screen "Your balance is untouched", laptop shows "Victims caught: 0", and a list of the four checks that ran.
- The bank is **fictional** ("SafeTrust Bank"), the screen carries a "SIMULATION" badge, and the money figures come from a fixture. The fake site's domain has no real RDAP record, so the demo calls the real engine through a clearly named `demoScenarioAdapter` that injects the domain-age and report-count signals (label "Demo scenario"). Never imitate a real brand.
- **"Try it yourself" box:** paste any link or message and get the real verdict (live adapters).
- **Privacy test:** an automated test proves that nothing typed or auto-typed in the demo is ever sent in a network request or stored in browser storage.
- Also deliver a **browser-extension block page** (MV3) reusing the same red warning for dangerous verdicts, if the extension exists in the repo.
- *Gate:* fixture table tests pass (fictional lookalikes, IP hosts, punycode, shorteners, HTTP login pages); SSRF tests pass (private IP, DNS rebinding, redirect to localhost all blocked); Playwright runs both scenarios end to end; the block screen's reasons equal the API response; privacy test passes.

### PHASE 5: Blockchain core (real, verifiable)
- **`BC-1b` Merkle batching:** leaves are **salted hashes** of canonical JSON (never names or emails). Build the Merkle tree (sorted-pair, OpenZeppelin `MerkleProof`-compatible), batch on a size or time threshold and on demand, anchor the **root** in `AuditAnchor.sol` (timestamp, submitter, event), store per-leaf inclusion proofs, expose `GET /receipts/{id}/proof`, and build a public **Verifier page** that checks a receipt against the on-chain root. Tests: Hardhat unit tests, an end-to-end flow (complete fix → leaf → batch → anchor → verifier OK), **tampering one byte fails**, gas report. Local Hardhat is default; Amoy optional via env.
- **`BC-2a` Real ZK-SNARKs:** circom 2 circuit proving `score ≥ threshold` where the score is bound to a **Poseidon commitment** (private: score, salt; public: commitment, threshold) with a range check on the score; Groth16 with snarkjs; use a public Powers-of-Tau file; generate the Solidity verifier and deploy it; proofs are generated **in the browser** (WASM) so private inputs never leave the device; anchor the commitment on-chain with a timestamp. A second circuit for selective disclosure (e.g., "all finance accounts have 2FA ≠ none") if time allows. Tests: valid witness verifies off-chain and on-chain; a **mutated proof**, a **wrong threshold** and a **score below the threshold** are all rejected; public inputs contain no score or account data. Replace or relabel every Ed25519 "ZKP" surface. Document in `LIMITATIONS.md` that the setup is not a production ceremony.
- *Gate:* all contract, circuit and e2e tests pass; the Verifier page accepts a real receipt and a real certificate and rejects tampered ones.

### PHASE 6: AI features, real or honestly relabeled
- **`AI-1c` Policy change tracking:** fetch policy pages (SSRF-safe), normalize text, store hashed snapshots, diff versions at sentence level, classify added/changed clauses (data selling, retention, cross-border transfer, government disclosure, third-party sharing, children's data) with rules plus an LLM summary that **quotes the exact clause** and never states what the text does not support; scheduled re-checks; alert on new high-risk clauses. Test with a local fixture server that serves v1 then v2 of a policy and assert the diff, flags and alert.
- **`AI-2b` Real breach-likelihood model:** dataset from the **HIBP public breaches catalog snapshot** (store with fetch date) plus curated sector/size tags. Build a company-period panel with features (past breach count, years since last breach, sector base rate, size bucket, sensitivity of exposed data classes) and the target "breached within the next 6/12 months". **Time-based split** (train earlier years, validate and test on later years), gradient boosting + isotonic calibration, and compare to a **base-rate baseline**. Report AUC, Brier score and a calibration plot in `docs/eval-report.md`. State the selection bias (the catalog only contains breaches that were disclosed and added) and present results as **relative risk estimates, not facts**. If the model cannot beat the baseline, say so and relabel the feature.
- **`M2-b` GNN:** train a PyTorch Geometric GraphSAGE/GAT on **synthetic account graphs** generated by a documented simulator, with labels from Monte Carlo compromise propagation. Evaluate on held-out graphs (Spearman correlation vs. ground truth; target ≥ 0.85). Ship it as an "AI estimate" shown **next to** the deterministic engine score (which remains the source of truth and fallback). If it cannot meet the target, remove the GNN claim and use the "Graph Risk Propagation Engine" name.
- **`AI-3` PrivacyBot:** verify it answers only from tool results (risk summary, simulate compromise, explain score, list fixes) and matches engine numbers; add a prompt-injection defense (account names, policy text and email content are untrusted data).
- *Gate:* `make eval` produces metrics; all labels in UI and docs match what is actually implemented.

### PHASE 7: Identity and DAO
- **`BC-3c` Web3 wallet:** Sign-In With Ethereum with a server-issued nonce, signature verification, and session creation; wallet connect via wagmi/viem (MetaMask + WalletConnect); `did:ethr` creation; an optional W3C Verifiable Credential for "score ≥ X". Playwright test using a programmatic wallet account. Be honest in the UI: DID login is an *additional* option and does not replace SSO on sites that do not support it.
- **`BC-4d` DAO token:** testnet-only ERC-20 (`PSToken`, no monetary value), report submission with stake, validator voting with quorum, rewards for verified reports, slashing for rejected ones. Tests: submit, vote, double-vote rejected, non-validator rejected, quorum reached, reward and slash balances correct. Verified reports feed the breach monitor as a **low-confidence** source until corroborated.

### PHASE 8: Remaining PDF features: verify and finish
Re-run the audit for M1, M2, M5, M6, AI-4, X1 to X6 and fix whatever is still Partial, Mocked-unlabeled or Broken. Specific requirements:
- Every dashboard widget reads from the API (no hardcoded numbers).
- Smart Import and CSV import never send plaintext passwords (assert in a Playwright network test).
- X1 "Hack Me": uses the real graph engine; damage report equals engine output; re-run after fixes shows a smaller chain.
- X3 Death Switch: the UI must state exactly which actions PrivacyShield performs itself and which are guided steps; never claim remote actions without an API.
- X5 Family Shield: explicit per-member consent; only aggregated or shared-edge data visible by default.
- X6 Broker opt-out: assisted workflow with real request templates (DPDP/GDPR/CCPA), tracking, and 30/60/90-day recheck reminders; no CAPTCHA bypassing.

### PHASE 9: Regression, polish and demo readiness
- Run the **full audit again** from scratch. Update every status with fresh evidence.
- Run security checks again (IDOR on every ID endpoint, plaintext-password scan of DB/logs/network, on-chain data scan, XSS and injection payloads, rate limits, SSRF).
- Accessibility (axe, keyboard walkthrough), Lighthouse (Performance ≥ 85, Accessibility ≥ 95), responsive checks, offline/error states.
- Add a **Judge Mode** route: one guided 5-minute flow: Phishing demo (unprotected, then protected) → Risk Graph with fix preview → "Try it yourself" link check → blockchain receipt verification. Include keyboard shortcuts, a reset button, and an offline `?mode=mock` flag.
- *Gate:* final audit shows **no Broken and no Missing items**, and every Mocked item is labeled in UI, code and `/status`.

---

