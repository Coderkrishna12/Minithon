# PrivacyShield 🛡️

> **Digital Footprint & Privacy Risk Auditor — AI + Blockchain Powered**

PrivacyShield is an end-to-end privacy and digital footprint analysis platform designed to help users identify, audit, monitor, and remediate exposures across their web accounts, credentials, and digital footprint.

---

## 🌟 Key Features

- **📊 Footprint & Risk Score Dashboard**: Unified dashboard aggregating active accounts, exposure severity, risk scores, and recommended privacy actions.
- **🕸️ Interactive Footprint Graph**: Visual representation of linked digital accounts, shared emails, authentication providers, and data exposure relationships.
- **🚨 Breach & Dark Web Monitoring**: Real-time integration and notifications for compromised credentials, data leaks, and dark web appearances.
- **🤖 AI Privacy Assistant**: Context-aware AI chat guiding users through privacy mitigation strategies, automated removal requests, and safety checklists.
- **⛓️ Blockchain Audit Trail & Web3**: Verifiable, immutable log of privacy audits, decentralized identity (DID) management, and community privacy DAO voting.
- **📥 Smart Account Import & Scanner**: Rapid discovery of digital footprints via scan, OAuth connections, and privacy exports.
- **👥 Family & Multi-Account Protection**: Shared privacy risk monitoring and alerts for family members and dependents.
- **📱 Cross-Platform Suite**: Web portal built with Next.js and native cross-platform mobile experience powered by Flutter.

---

## 🏗️ Repository Architecture

```text
privacyshield/
├── backend/            # FastAPI async REST & WebSocket backend (Python)
│   ├── app/
│   │   ├── api/        # Routers (auth, accounts, breaches, ai_chat, did, dao, etc.)
│   │   ├── core/       # App configuration and security settings
│   │   ├── db/         # SQLAlchemy async engine, models, and session management
│   │   ├── models/     # Database entities
│   │   ├── schemas/    # Pydantic request/response schemas
│   │   └── services/   # Business logic (AI, blockchain, risk calculation)
│   ├── requirements.txt
│   └── .env.example
├── frontend/           # Modern web dashboard built with Next.js & TypeScript
│   ├── src/app/        # App router pages (dashboard, accounts, breaches, graph, etc.)
│   ├── src/components/ # UI and interaction components
│   └── package.json
└── mobile/             # Cross-platform mobile application (Flutter / Dart)
    ├── lib/            # Screens (AR scanner, dashboard, reports, DAO, etc.)
    └── pubspec.yaml
```

---

## 🚀 Getting Started

### 1. Backend Setup

```bash
cd backend
python -m venv .venv
# Activate environment (Windows: .venv\Scripts\activate, Unix: source .venv/bin/activate)
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
API Documentation will be available at `http://localhost:8000/docs`.

### 2. Frontend Setup

```bash
cd frontend
npm install
npm run dev
```
Web application will be running at `http://localhost:3000`.

### 3. Mobile Setup

```bash
cd mobile
flutter pub get
flutter run
```

---

## 🔒 Security & Privacy

PrivacyShield is designed with privacy-by-design principles:
- Credentials and tokens are never stored in plain text.
- On-chain privacy logs store cryptographic hashes rather than personal data.
- SQLite / local relational DB support for local self-hosted deployments.

---

## 📄 License

This project is licensed under the MIT License.
