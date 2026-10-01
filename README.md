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
python run.py
```
`run.py` installs anything missing, opens port 8000 in Windows Firewall (or prints the one Administrator command to do it), sets up `adb reverse` for a USB-connected phone, prints the addresses a phone can use, and serves on all interfaces. API docs: `http://localhost:8000/docs`.

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
On launch the app finds the backend by itself: the last server that worked, USB (`adb reverse`), the emulator, then a sweep of the phone's Wi-Fi subnet. If nothing answers it opens a setup screen where you can type the PC's IP. To pin an address at build time: `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api`.

If a phone on the same Wi-Fi still can't connect, the network is probably isolating devices (common on college and public Wi-Fi): connect by USB, or put the PC on the phone's hotspot.

---

## 🔒 Security & Privacy

PrivacyShield is designed with privacy-by-design principles:
- Credentials and tokens are never stored in plain text.
- On-chain privacy logs store cryptographic hashes rather than personal data.
- SQLite / local relational DB support for local self-hosted deployments.

---

## 📄 License

This project is licensed under the MIT License.
