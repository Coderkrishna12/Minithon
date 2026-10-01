# PrivacyShield — Feature Checklist (Derived from PDF)

> **Audit date:** 2026-10-01  
> **Source:** `PrivacyShield_Features.pdf` (parsed via `generate_pdf.py`)  
> **Scope:** Web App column only. Mobile-exclusive items noted as "Out of scope: mobile."

---

## CORE FEATURES

| ID | Feature | Exact Promise from PDF | Where in Web UI | How to Test |
|----|---------|------------------------|-----------------|-------------|
| M1-a | Manual Add | Add accounts with service name, email used, 2FA status, password-reuse group label, recovery methods | `/accounts` page + `POST /api/accounts/` | Create account via API with all fields; verify it appears in list and persists after reload |
| M1-b | Smart Import (Email Inbox) | Auto-detect accounts from email inbox scanning (OAuth read-only), browser extensions | `/accounts` import flow + `POST /api/import/*` | Run fixture-mailbox scan; confirm accounts are created; inspect payloads for no real passwords |
| M1-c | App Permission Scanner | Native integration with Android/iOS permission APIs | N/A for web | **Out of scope: mobile** (PDF says "Browser Ext Only" for web) |
| M1-d | SSO & Recovery Chain Mapping | Map which accounts use Google/Apple/Facebook SSO, and which emails serve as recovery | `/graph` page + `POST /api/accounts/connections` | Create SSO + recovery_email edges; verify edges appear on graph |
| M1-e | Password Reuse Groups | Label accounts sharing the same password — see how many doors one leaked password opens | `/accounts` + `password_group` field | Put 3 accounts in one group; verify UI shows reuse count |
| M1-f | Blockchain Anchor | Hash of your full inventory stored on-chain as a timestamped snapshot | `GET /api/blockchain/chain` | Add an account; verify a hash/block is created in audit chain |
| M1-g | Edit Account | Edit existing account details | `PUT /api/accounts/{id}` | Update service_name, 2FA; verify changes persist |
| M1-h | Delete Account | Delete an account | `DELETE /api/accounts/{id}` | Delete; verify 204 and account gone from list |
| M1-i | Validation | Empty service name, invalid email, duplicate rejected with clear messages | `POST /api/accounts/` | Send empty service_name, bad data; expect 422 or 400 |
| M2-a | Interactive Account Graph | Visual force-directed graph showing every account as a node, with edges for SSO, recovery, shared passwords, data-sharing | `/graph` page (Canvas-based) | Load graph page; verify nodes/edges render; zoom/pan/drag/click |
| M2-b | Cascading Risk Engine (GNN) | Graph Neural Network propagates risk through connections | Risk engine at `services/risk_engine.py` | Check if a real GNN model is used or a deterministic formula |
| M2-c | Risk Score Formula | breach 30% + permission scope 20% + password reuse 20% + missing 2FA 15% + cascading impact 15% | `score_network()` function | Compute by hand for 3 accounts; compare with app output |
| M2-d | Breach History Integration | Auto-check against HaveIBeenPwned; flag compromised credentials | `POST /api/breaches/scan` | Scan a known-breached email; check if live or mock |
| M2-e | Single Point of Failure Detection | AI identifies "keystone" accounts | `GET /api/dashboard/` → `single_points_of_failure` | Create weak email that recovers 10 accounts; verify it's flagged |
| M2-f | Network-Wide Privacy Score | Overall 0-100 score reflecting entire digital footprint health | `GET /api/dashboard/` → `privacy_score` | Verify 0-100; add/fix accounts and confirm it changes |
| M3-a | Priority-Ranked Fix Actions | AI ranks fixes by network-wide risk reduction | `GET /api/dashboard/fixes` | Verify fix list is ordered by risk_reduction desc |
| M3-b | Fix Impact Preview | Before/after risk score simulation | `GET /api/dashboard/fixes/{id}/preview` | Get preview; complete fix; verify new score equals previewed score |
| M3-c | One-Tap Fix Links (Deep Links) | Deep-links to each service's security settings page | Fix description / UI | Check if fix descriptions contain URLs to service security pages |
| M3-d | Guided Walkthroughs | Step-by-step visual guides for non-technical users | UI | Look for walkthrough/guide content on fix actions |
| M3-e | Progress Tracking | Checklist tracks completed vs. pending fixes with completion % and estimated time | Dashboard + fix list | Complete fixes; verify completion % updates |
| M3-f | Blockchain Fix Receipt | Each completed fix is hashed on-chain | `PATCH /api/dashboard/fixes/{id}/complete` response | Complete a fix; verify `blockchain_tx_hash` is present |
| M4-a | Global Search | Instant search across accounts, services, permissions, risk levels, fix actions | `/search` page + `GET /api/search/?q=` | Search by account name, category, breach; verify results |
| M4-b | Smart Filters | Filter by risk level, service type, 2FA status, data shared, last activity date | `GET /api/accounts/?category=&risk_level=` | Apply multiple filters; verify correct filtering |
| M4-c | Graph Filters | Show only SSO chains, password-reuse clusters, or recovery links | `/graph` page edge filter | Toggle each filter; verify graph updates |
| M4-d | Timeline View | See when each account was added, last audited, breach history chronologically | `/timeline` page + `GET /api/timeline/` | Verify events appear in chronological order |
| M5-a | Real-Time Breach Monitor | Continuous background scanning; instant push notification (web) | WebSocket at `/ws/breach-monitor` | Connect WebSocket; trigger breach; verify alert arrives |
| M5-b | Cascade Alert | When one service is breached, AI maps downstream accounts + emergency checklist | Notification system | Trigger breach on keystone account; verify cascade alert |
| M5-c | Periodic Review Reminders | Scheduled prompts (weekly/monthly) | `GET /api/reminders/` | Create reminder; verify next_trigger date is set |
| M5-d | Dark Web Scanning | NLP-powered scanning of dark web paste sites | `POST /api/darkweb/scan` | Run scan; determine if real, third-party API, or mock |
| M5-e | Smart Notification Priority | AI categorizes alerts as Critical/Warning/Info | `GET /api/notifications/` | Verify notifications have severity field with correct values |
| M6-a | Overall Privacy Score Gauge | Large 0-100 gauge with trend arrow | `/dashboard` | Verify gauge renders with score from API |
| M6-b | Risk Heatmap | Accounts colored by risk level on graph | `/graph` page | Verify node colors correspond to risk levels |
| M6-c | Top 3 SPOFs | Top 3 keystone accounts highlighted | `/dashboard` → SPOFs section | Verify ≤3 SPOFs shown with cascading impact |
| M6-d | Fix Progress Ring | Completion ring showing % of fixes done | `/dashboard` | Verify fix completion stats render |
| M6-e | Connection Graph Mini-Map | Zoomable mini-view of full account network | `/graph` page minimap canvas | Verify minimap canvas renders |
| M6-f | Improvement Timeline | Historical chart showing privacy score over weeks/months | `/timeline` or `/dashboard` + `GET /api/dashboard/score-history` | Verify score history data exists and renders |
| M6-g | Breach Exposure Summary | Count of breaches, total records exposed, remediation status | `/dashboard` → `breaches_found` | Verify breach count from API matches display |

## AI FEATURES

| ID | Feature | Exact Promise from PDF | Where in Web UI | How to Test |
|----|---------|------------------------|-----------------|-------------|
| AI-1a | Auto-Scan T&Cs | NLP model ingests Terms of Service / Privacy Policies | `POST /api/ai/analyze-policy` | Submit a real policy URL; check result |
| AI-1b | Plain-English Summaries | Converts legalese into simple risk summaries | Response from analyze-policy | Verify summary field is human-readable |
| AI-1c | Change Detection | Monitors policy updates and alerts on new clauses | N/A | Check if stored/re-scan mechanism exists |
| AI-1d | Risk Flags | Auto-flags data selling, indefinite retention, cross-border, government disclosure | Response `risk_flags` field | Verify flags are set based on actual policy text |
| AI-2a | Per-Account Breach Probability | Each account gets a predicted breach probability for next 6 months | `GET /api/ai/breach-predictions` | Verify values differ by sector/history, are 0-1 |
| AI-2b | Model & Training Data | ML model trained on breach frequency, company size, sector patterns | `predict_breach_probability()` function | Inspect if real ML model or rule-based formula |
| AI-3a | PrivacyBot Chat | Natural language queries about digital security | `/ai-chat` page + `POST /api/ai/chat` | Ask the 3 PDF examples; verify answers use actual account data |
| AI-3b | Scenario Simulation | "What if my phone is stolen?" — simulates attack chain | `POST /api/ai/chat` | Ask scenario question; verify graph-aware response |
| AI-3c | Prompt Injection Resistance | Bot should not be hijacked | `POST /api/ai/chat` | Put "ignore previous instructions" in account name; test |
| AI-4a | Permission vs. Usage Analysis | Cross-reference granted permissions with app category | `GET /api/ai/permission-advisor` | Create a calculator app with microphone; verify flagged |
| AI-4b | Bulk Revoke Suggestions | One-tap list of permissions you can safely revoke | Response `unnecessary_permissions` | Verify unnecessary permissions listed |
| AI-4c | App Alternatives | AI suggests privacy-respecting alternatives | Response | Check if alternatives are provided |

## BLOCKCHAIN FEATURES

| ID | Feature | Exact Promise from PDF | Where in Web UI | How to Test |
|----|---------|------------------------|-----------------|-------------|
| BC-1a | On-Chain Hashing | SHA-256 hash of every audit snapshot on Polygon/Ethereum L2 | `GET /api/blockchain/chain` | Perform action; verify hash created |
| BC-1b | Merkle Tree Batching | Batch multiple actions into Merkle tree roots | Blockchain service | Check if Merkle tree is used |
| BC-1c | Tamper-Proof Verification | No one can alter privacy audit history | `GET /api/blockchain/verify/{block}` | Tamper with a value; confirm verification fails |
| BC-1d | On-Chain Anchoring | Real transaction on Polygon testnet | `ChainAnchor` model + anchor function | Check if `POLYGON_PRIVATE_KEY` is set; verify tx exists |
| BC-2a | ZK-SNARK Certificates | Generate cryptographic proof that score ≥ threshold without revealing accounts | `POST /api/blockchain/zkp-certificate` | Generate certificate; verify it contains proof |
| BC-2b | ZKP Verification | Verifier can check proof without accessing data | `POST /api/blockchain/attestations/verify` | Submit valid/invalid proof; verify pass/fail |
| BC-2c | ZKP does not leak data | Public inputs don't contain score or accounts | Response inspection | Check proof does not reveal score or account list |
| BC-3a | Create DID | W3C standard DID anchored on blockchain | `POST /api/did/create` | Create DID; verify did:key format |
| BC-3b | DID Verification | Verify credential and portable history | `POST /api/did/verify` | Verify DID; check credentials valid |
| BC-3c | Wallet Integration | MetaMask / WalletConnect for blockchain interactions | UI | Check if wallet connect UI exists |
| BC-4a | Breach Report DAO | Anyone can submit a breach report; community validators verify | `POST /api/dao/proposals` | Submit proposal; verify it appears |
| BC-4b | Voting | Vote with validators; reach quorum | `POST /api/dao/proposals/{id}/vote` | Vote; verify vote counts |
| BC-4c | Quorum & Outcomes | Confirmed status when votes_for >= 5 | DAO proposal status | Vote 5 times for; verify status changes |
| BC-4d | Incentivized Reporting | Token rewards for verified breach reports | N/A | Check if token/reward mechanism exists |

## CRAZY EXTRA FEATURES

| ID | Feature | Exact Promise from PDF | Where in Web UI | How to Test |
|----|---------|------------------------|-----------------|-------------|
| X1-a | Hack Me — Choose Entry Point | Pick any account and simulate it being compromised | `/graph` page → "Simulate Attack" button | Select node; click simulate |
| X1-b | Animated Attack Chain | Watch attack propagate through graph in real-time — each hop lights up red | Graph canvas animation | Verify canvas shows compromised nodes in red |
| X1-c | Damage Report | Total accounts reachable, data exposed, financial accounts at risk | Attack result panel | Verify numbers match graph engine |
| X1-d | Before/After | Run simulation after fixes; see attack chain shrink | Graph page | Complete a fix; re-run simulation; compare |
| X2-a | Dynamic NFT Badge | SVG-based NFT that visually changes based on privacy score | `/badges` page + `POST /api/features/badges/mint/{type}` | Mint badge; verify token_id and tx_hash |
| X2-b | Achievement Badges | Earn special NFTs for milestones | Badge types list | Verify eligibility logic for each badge type |
| X3-a | Panic Button (Digital Death Switch) | Single tap triggers emergency actions across all accounts | `POST /api/features/lockdown` | Trigger lockdown; verify actions returned |
| X3-b | Auto-Actions | Revoke sessions, trigger password resets, enable lockout | Response `actions` field | Verify claimed vs actual actions |
| X3-c | Recovery Plan | Pre-built recovery sequence | Response `recovery_steps` | Verify recovery steps provided |
| X4-a | Digital Twin Simulation | AI creates virtual twin; stress-tests against threats | `POST /api/ai/digital-twin` | Run simulation; verify attack vectors found |
| X4-b | Vulnerability Discovery | Finds attack paths you'd never think of | Response `attack_vectors` | Verify vectors use actual account data |
| X5-a | Family Group Create | Create family/team group | `POST /api/family/groups` | Create group; verify invite code |
| X5-b | Family Join | Join via invite code | `POST /api/family/join` | Join with code; verify membership |
| X5-c | Family Dashboard | See family members' scores and risk | `GET /api/family/dashboard/{id}` | Verify aggregate stats |
| X5-d | Consent Steps | Consent mechanisms for family sharing | Join flow | Verify consent is required |
| X6-a | Data Broker Discovery | AI scans known data broker databases | `GET /api/features/data-brokers` | Verify broker list returned |
| X6-b | Auto Opt-Out | Auto-fills and submits opt-out forms | `POST /api/features/data-brokers/opt-out-all` | Verify if requests are actually submitted or just links |
| X6-c | Verification Follow-Up | Re-checks after 30/60/90 days | N/A | Check if follow-up mechanism exists |
| X7 | AR Privacy Scanner | Point camera at apps for privacy overlay | N/A | **Out of scope: mobile exclusive** |

## WEB MATRIX ITEMS (from PDF Feature Matrix — "Web App" column)

| ID | Feature | Web Column Value | How to Test |
|----|---------|------------------|-------------|
| WM-1 | Account Inventory & Import | Yes | Covered by M1-* |
| WM-2 | Interactive Account Graph | Full (D3.js) | Covered by M2-a — verify if D3.js or Canvas |
| WM-3 | App Permission Scanner | Browser Ext Only | Check if browser extension exists |
| WM-4 | AI Risk Scoring Engine | Yes | Covered by M2-b,c |
| WM-5 | PrivacyBot Chat | Yes | Covered by AI-3a |
| WM-6 | Breach Alerts | Browser Push | Test browser push notification |
| WM-7 | Attack Simulator | Full Animated | Covered by X1-* |
| WM-8 | Privacy Dashboard | Full Desktop | Covered by M6-* |
| WM-9 | AR Privacy Scanner | No | **Out of scope** |
| WM-10 | Panic Button / Lockdown | Yes | Covered by X3-* |
| WM-11 | Biometric Auth | WebAuthn | Test WebAuthn support |
| WM-12 | NFT Badge Minting | Yes | Covered by X2-* |
| WM-13 | ZKP Certificate | Yes | Covered by BC-2-* |
| WM-14 | Offline Mode | No | N/A |
| WM-15 | Dark Web Scan | Yes | Covered by M5-d |
| WM-16 | Data Broker Opt-Out | Yes | Covered by X6-* |
| WM-17 | Family Shield | Yes | Covered by X5-* |

## TECH STACK CLAIMS

| ID | Claim | Actual | How to Verify |
|----|-------|--------|---------------|
| TS-1 | Frontend: React.js / Next.js + TailwindCSS + D3.js/Cytoscape.js | Check package.json | Inspect dependencies |
| TS-2 | Backend: FastAPI + WebSocket + Redis caching | Check requirements.txt + main.py | Verify WebSocket handler; check for Redis |
| TS-3 | AI/ML: PyTorch Geometric for GNN + HuggingFace + scikit-learn + LangChain/Claude | Check requirements.txt + services | Verify what ML libraries are actually used |
| TS-4 | Database: PostgreSQL + Neo4j + MongoDB | Check config + session.py | Verify actual DB engine used |
| TS-5 | Blockchain: Polygon L2 + Solidity smart contracts + ZK-SNARKs (circom/snarkjs) + IPFS | Check blockchain service | Verify what's actually deployed |
| TS-6 | Breach Intelligence: HIBP API + custom dark web scraper (Tor-based) + DAO | Check breach_checker.py + darkweb.py | Verify data sources |
| TS-7 | Auth: OAuth 2.0 + AES-256 encryption + E2E encryption + DID/VC | Check security.py + config | Verify encryption and auth mechanisms |
| TS-8 | Infra: Docker + Kubernetes + AWS/GCP + CI/CD + Grafana/Prometheus | Check for Dockerfile, k8s manifests, CI configs | Verify what infra files exist |

## UNIQUE SELLING POINTS

| ID | Claim | How to Verify |
|----|-------|---------------|
| USP-1 | "Not just a checker — a network analyzer": cascading risk across entire account graph | Prove with graph cascade test |
| USP-2 | "Blockchain-verified trust": provably immutable | Tamper test on audit chain |
| USP-3 | "AI that thinks like a hacker": attack simulator uses YOUR accounts | Run attack sim; verify it uses real graph |
| USP-4 | "Zero-Knowledge compliance": prove security without revealing anything | Invalid proof test |
| USP-5 | "Cross-platform parity": full experience on web AND mobile | Compare web vs mobile features |
| USP-6 | "Community-powered intelligence": decentralized breach reporting DAO | Test DAO proposal flow |
