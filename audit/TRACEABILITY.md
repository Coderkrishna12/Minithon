# PrivacyShield — Traceability Matrix

> Feature ID → implementing files. **Missing** = no code found.

| Feature ID | Files | Notes |
|-----------|-------|-------|
| **M1-a** Manual Add | [accounts.py](file:///d:/Minithon/backend/app/api/accounts.py) L40-51, [AccountCreate schema](file:///d:/Minithon/backend/app/schemas/account.py), [Account model](file:///d:/Minithon/backend/app/models/account.py) L6-38 | ✅ Implemented |
| **M1-b** Smart Import | [smart_import.py](file:///d:/Minithon/backend/app/api/smart_import.py) L74-97 (fixture), L100-131 (CSV), L134-167 (email scan), L170-225 (bulk-add) | ✅ Multiple import paths implemented; fixture clearly labeled "DEMO DATA" |
| **M1-c** App Permission Scanner | N/A | **Out of scope: mobile** |
| **M1-d** SSO & Recovery Chain | [accounts.py](file:///d:/Minithon/backend/app/api/accounts.py) L103-118 (connections), [connections.py](file:///d:/Minithon/backend/app/services/connections.py), [graph.py](file:///d:/Minithon/backend/app/api/graph.py) | ✅ Implemented |
| **M1-e** Password Reuse Groups | [Account model](file:///d:/Minithon/backend/app/models/account.py) L18 `password_group`, [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) L103-107 | ✅ Implemented |
| **M1-f** Blockchain Anchor | [blockchain.py](file:///d:/Minithon/backend/app/services/blockchain.py) L76-100 (record_audit), L44-61 (send_anchor_tx) | ✅ Hash chain + optional Polygon anchoring |
| **M1-g** Edit Account | [accounts.py](file:///d:/Minithon/backend/app/api/accounts.py) L67-85 | ✅ Implemented |
| **M1-h** Delete Account | [accounts.py](file:///d:/Minithon/backend/app/api/accounts.py) L88-100 | ✅ Implemented |
| **M1-i** Validation | [AccountCreate schema](file:///d:/Minithon/backend/app/schemas/account.py) | Pydantic validation; need to check specifics |
| **M2-a** Interactive Graph | [graph/page.tsx](file:///d:/Minithon/frontend/src/app/graph/page.tsx) (Canvas-based, custom force simulation), [graph.py](file:///d:/Minithon/backend/app/api/graph.py) | ✅ **Canvas, NOT D3.js** (PDF claims D3.js/Cytoscape.js) |
| **M2-b** Cascading Risk (GNN) | [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) | ❌ **No GNN**. Deterministic formula. The file header says "No trained model is claimed." |
| **M2-c** Risk Score Formula | [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) L123 | ✅ Weights match PDF: 0.30*breach + 0.20*permission + 0.20*reuse + 0.15*2FA + 0.15*cascade |
| **M2-d** Breach History | [breach_checker.py](file:///d:/Minithon/backend/app/services/breach_checker.py) | ✅ Real HIBP/XON integration with mock fallback |
| **M2-e** SPOF Detection | [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) L190-197 | ✅ Implemented |
| **M2-f** Privacy Score | [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) L157 | ✅ 0-100 score |
| **M3-a** Fix Actions | [risk_engine.py](file:///d:/Minithon/backend/app/services/risk_engine.py) L200-247, [dashboard.py](file:///d:/Minithon/backend/app/api/dashboard.py) L71-86 | ✅ Ranked by risk_reduction |
| **M3-b** Fix Preview | [dashboard.py](file:///d:/Minithon/backend/app/api/dashboard.py) L135-181 | ✅ Before/after simulation |
| **M3-c** Deep Links | No deep-link URLs in fix descriptions | ❌ **Missing**: fixes say "Enable 2FA on Gmail" but no link |
| **M3-d** Guided Walkthroughs | No walkthrough content found | ❌ **Missing** |
| **M3-e** Progress Tracking | [dashboard.py](file:///d:/Minithon/backend/app/api/dashboard.py) L37-40 | ⚠️ Counts exist but no estimated time or completion ring |
| **M3-f** Blockchain Fix Receipt | [dashboard.py](file:///d:/Minithon/backend/app/api/dashboard.py) L124-131 | ✅ Fix completion creates audit log entry |
| **M4-a** Global Search | [search.py](file:///d:/Minithon/backend/app/api/search.py), [search/page.tsx](file:///d:/Minithon/frontend/src/app/search) | ✅ Searches accounts, breaches, notifications, audit logs |
| **M4-b** Smart Filters | [accounts.py](file:///d:/Minithon/backend/app/api/accounts.py) L20-36 | ⚠️ Only category + risk_level filters; missing 2FA status, data shared, last activity filters |
| **M4-c** Graph Filters | [graph/page.tsx](file:///d:/Minithon/frontend/src/app/graph/page.tsx) L51-57, L67-98 | ✅ Edge type + category filters |
| **M4-d** Timeline View | [timeline.py](file:///d:/Minithon/backend/app/api/timeline.py), [timeline/page.tsx](file:///d:/Minithon/frontend/src/app/timeline) | ✅ Implemented |
| **M5-a** Real-Time Breach Monitor | [websocket.py](file:///d:/Minithon/backend/app/api/websocket.py) | ⚠️ WebSocket exists but no browser push notifications (requires FCM/service worker) |
| **M5-b** Cascade Alert | No cascade-specific alert logic found | ❌ **Missing**: breach triggers notifications but no cascade mapping |
| **M5-c** Review Reminders | [reminders.py](file:///d:/Minithon/backend/app/api/reminders.py) | ✅ CRUD exists |
| **M5-d** Dark Web Scanning | [darkweb.py](file:///d:/Minithon/backend/app/api/darkweb.py) | ⚠️ Uses HIBP/XON paste data, NOT Tor-based custom scraper |
| **M5-e** Notification Priority | [Notification model](file:///d:/Minithon/backend/app/models/account.py) L122-132 | ✅ severity field (critical/warning/info) |
| **M6-a** Score Gauge | [dashboard/page.tsx](file:///d:/Minithon/frontend/src/app/dashboard/page.tsx), [ScoreRing.tsx](file:///d:/Minithon/frontend/src/components/ScoreRing.tsx) | ✅ Score rendered |
| **M6-b** Risk Heatmap | [graph/page.tsx](file:///d:/Minithon/frontend/src/app/graph/page.tsx) L37-42 | ✅ Nodes colored by risk level |
| **M6-c** Top 3 SPOFs | [dashboard/page.tsx](file:///d:/Minithon/frontend/src/app/dashboard/page.tsx) L89-103 | ✅ Rendered |
| **M6-d** Fix Progress Ring | [dashboard/page.tsx](file:///d:/Minithon/frontend/src/app/dashboard/page.tsx) | ⚠️ Shows pending/done counts, no ring visualization |
| **M6-e** Minimap | [graph/page.tsx](file:///d:/Minithon/frontend/src/app/graph/page.tsx) L245-278, L373-382 | ✅ Minimap canvas |
| **M6-f** Improvement Timeline | [ScoreHistory model](file:///d:/Minithon/backend/app/models/account.py) L150-161 | ⚠️ Data model exists; need to verify frontend renders chart |
| **M6-g** Breach Exposure Summary | [dashboard.py](file:///d:/Minithon/backend/app/api/dashboard.py) L35 | ⚠️ breach count only; no "total records exposed" count |
| **AI-1a** Policy Analysis | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L139-241 | ✅ Real URL fetch + keyword fallback + optional Claude analysis |
| **AI-1b** Plain-English Summary | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L219-227 | ✅ When Claude key available; keyword-only without |
| **AI-1c** Change Detection | None found | ❌ **Missing**: no stored policy diffing mechanism |
| **AI-1d** Risk Flags | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L141-150 | ✅ 8 categories of risk flags |
| **AI-2a** Breach Probability | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L406-444 | ✅ Rule-based formula (not ML model) |
| **AI-2b** ML Model | None | ❌ **No ML model**. Pure rule-based formula |
| **AI-3a** PrivacyBot Chat | [ai_chat.py](file:///d:/Minithon/backend/app/api/ai_chat.py) L28-35, [rag/pipeline.py](file:///d:/Minithon/backend/app/services/rag/pipeline.py) | ✅ RAG pipeline with Claude; user context included |
| **AI-3b** Scenario Sim | Covered by chat context | ⚠️ No dedicated scenario sim; relies on Claude interpretation |
| **AI-4a** Permission Advisor | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L244-307 | ✅ Category-based permission analysis |
| **BC-1a** On-Chain Hashing | [blockchain.py](file:///d:/Minithon/backend/app/services/blockchain.py) | ✅ SHA-256 hash chain |
| **BC-1b** Merkle Batching | None | ❌ **Missing**: no Merkle tree; individual blocks chained |
| **BC-1c** Tamper Detection | [blockchain.py](file:///d:/Minithon/backend/app/services/blockchain.py) L103-146 | ✅ Chain integrity verification |
| **BC-1d** Polygon Anchoring | [blockchain.py](file:///d:/Minithon/backend/app/services/blockchain.py) L44-73 | ✅ When POLYGON_PRIVATE_KEY set; optional |
| **BC-2a** ZKP/Attestation | [blockchain.py](file:///d:/Minithon/backend/app/services/blockchain.py) L149-165 | ⚠️ **Not ZK-SNARKs**. Ed25519 signed attestation; reveals the boolean result. No circom/snarkjs. |
| **BC-2b** Attestation Verify | [blockchain.py](file:///d:/Minithon/backend/app/api/blockchain.py) L98-102 | ✅ Signature verification works |
| **BC-3a** DID Create | [did.py](file:///d:/Minithon/backend/app/api/did.py) L32-83 | ✅ did:key with Ed25519 |
| **BC-3b** DID Verify | [did.py](file:///d:/Minithon/backend/app/api/did.py) L109-132 | ✅ Credential verification |
| **BC-3c** Wallet Integration | None found in frontend | ❌ **Missing**: no MetaMask/WalletConnect UI |
| **BC-4a** DAO Proposals | [dao.py](file:///d:/Minithon/backend/app/api/dao.py) L68-94 | ✅ |
| **BC-4b** Voting | [dao.py](file:///d:/Minithon/backend/app/api/dao.py) L97-144 | ✅ |
| **BC-4c** Quorum | [dao.py](file:///d:/Minithon/backend/app/api/dao.py) L128-129 | ✅ votes_for >= 5 → confirmed |
| **BC-4d** Token Rewards | None | ❌ **Missing**: no token/reward system |
| **X1-a** Hack Me Entry | [graph.py](file:///d:/Minithon/backend/app/api/graph.py) L62-118 | ✅ simulate-attack endpoint |
| **X1-b** Animated Chain | [graph/page.tsx](file:///d:/Minithon/frontend/src/app/graph/page.tsx) L194-203, L207-218 | ⚠️ Compromised nodes shown in red; no step-by-step animation |
| **X1-c** Damage Report | [graph.py](file:///d:/Minithon/backend/app/api/graph.py) L111-118 | ✅ Returns total compromised, financial at risk |
| **X1-d** Before/After | Graph page allows re-running after fixes | ⚠️ Manual re-run; no side-by-side comparison |
| **X2-a** NFT Badge | [features.py](file:///d:/Minithon/backend/app/api/features.py) L17-133 | ⚠️ Local NFT record with blockchain audit; NOT on-chain NFT mint |
| **X3-a** Lockdown/Panic | [features.py](file:///d:/Minithon/backend/app/api/features.py) L138-184 | ⚠️ Returns checklist; does NOT actually revoke sessions/reset passwords |
| **X4-a** Digital Twin | [ai_engine.py](file:///d:/Minithon/backend/app/services/ai_engine.py) L310-403 | ✅ Attack vector analysis based on real accounts |
| **X5-a** Family Create | [family.py](file:///d:/Minithon/backend/app/api/family.py) L25-51 | ✅ |
| **X5-b** Family Join | [family.py](file:///d:/Minithon/backend/app/api/family.py) L104-128 | ✅ |
| **X5-c** Family Dashboard | [family.py](file:///d:/Minithon/backend/app/api/family.py) L163-218 | ✅ |
| **X6-a** Data Broker List | [features.py](file:///d:/Minithon/backend/app/api/features.py) L189-207 | ⚠️ Static list of brokers; no actual scanning |
| **X6-b** Auto Opt-Out | [features.py](file:///d:/Minithon/backend/app/api/features.py) L210-243 | ❌ Returns links only; does NOT submit forms |
