from reportlab.lib.pagesizes import A4
from reportlab.lib.units import inch, mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.pdfgen import canvas
from reportlab.lib import colors
import os

# ── Colors ──
DARK_BG = HexColor("#0F172A")
ACCENT_BLUE = HexColor("#3B82F6")
ACCENT_CYAN = HexColor("#06B6D4")
ACCENT_PURPLE = HexColor("#8B5CF6")
ACCENT_GREEN = HexColor("#10B981")
ACCENT_ORANGE = HexColor("#F59E0B")
ACCENT_RED = HexColor("#EF4444")
ACCENT_PINK = HexColor("#EC4899")
LIGHT_BG = HexColor("#F8FAFC")
CARD_BG = HexColor("#F1F5F9")
BORDER = HexColor("#E2E8F0")
TEXT_DARK = HexColor("#1E293B")
TEXT_MED = HexColor("#475569")
TEXT_LIGHT = HexColor("#94A3B8")

output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "PrivacyShield_Features.pdf")

doc = SimpleDocTemplate(
    output_path,
    pagesize=A4,
    topMargin=0.6*inch,
    bottomMargin=0.6*inch,
    leftMargin=0.7*inch,
    rightMargin=0.7*inch,
)

# ── Styles ──
styles = {}
styles["hero_title"] = ParagraphStyle(
    "hero_title", fontName="Helvetica-Bold", fontSize=28, leading=34,
    textColor=ACCENT_BLUE, alignment=TA_CENTER, spaceAfter=6
)
styles["hero_sub"] = ParagraphStyle(
    "hero_sub", fontName="Helvetica", fontSize=12, leading=16,
    textColor=TEXT_MED, alignment=TA_CENTER, spaceAfter=4
)
styles["hero_tagline"] = ParagraphStyle(
    "hero_tagline", fontName="Helvetica-BoldOblique", fontSize=14, leading=18,
    textColor=ACCENT_PURPLE, alignment=TA_CENTER, spaceAfter=20
)
styles["section_title"] = ParagraphStyle(
    "section_title", fontName="Helvetica-Bold", fontSize=18, leading=22,
    textColor=ACCENT_BLUE, spaceBefore=18, spaceAfter=10
)
styles["subsection"] = ParagraphStyle(
    "subsection", fontName="Helvetica-Bold", fontSize=13, leading=17,
    textColor=ACCENT_PURPLE, spaceBefore=12, spaceAfter=6
)
styles["body"] = ParagraphStyle(
    "body", fontName="Helvetica", fontSize=10, leading=14,
    textColor=TEXT_DARK, alignment=TA_JUSTIFY, spaceAfter=6
)
styles["bullet"] = ParagraphStyle(
    "bullet", fontName="Helvetica", fontSize=10, leading=14,
    textColor=TEXT_DARK, leftIndent=18, spaceAfter=4, bulletIndent=6
)
styles["sub_bullet"] = ParagraphStyle(
    "sub_bullet", fontName="Helvetica", fontSize=9.5, leading=13,
    textColor=TEXT_MED, leftIndent=36, spaceAfter=3, bulletIndent=22
)
styles["card_title"] = ParagraphStyle(
    "card_title", fontName="Helvetica-Bold", fontSize=12, leading=15,
    textColor=white, spaceAfter=4
)
styles["card_body"] = ParagraphStyle(
    "card_body", fontName="Helvetica", fontSize=9.5, leading=13,
    textColor=HexColor("#CBD5E1"), spaceAfter=2
)
styles["badge"] = ParagraphStyle(
    "badge", fontName="Helvetica-Bold", fontSize=8, leading=10,
    textColor=white, alignment=TA_CENTER
)
styles["footer"] = ParagraphStyle(
    "footer", fontName="Helvetica", fontSize=8, leading=10,
    textColor=TEXT_LIGHT, alignment=TA_CENTER
)
styles["tech_label"] = ParagraphStyle(
    "tech_label", fontName="Helvetica-Bold", fontSize=10, leading=13,
    textColor=ACCENT_CYAN, spaceAfter=2
)
styles["tech_body"] = ParagraphStyle(
    "tech_body", fontName="Helvetica", fontSize=9.5, leading=13,
    textColor=TEXT_DARK, spaceAfter=6
)
styles["crazy_title"] = ParagraphStyle(
    "crazy_title", fontName="Helvetica-Bold", fontSize=13, leading=17,
    textColor=ACCENT_PINK, spaceBefore=10, spaceAfter=4
)
styles["crazy_bullet"] = ParagraphStyle(
    "crazy_bullet", fontName="Helvetica", fontSize=10, leading=14,
    textColor=TEXT_DARK, leftIndent=18, spaceAfter=4, bulletIndent=6
)

story = []

def add_divider(color=BORDER):
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=1.5, color=color, spaceBefore=2, spaceAfter=8))

def add_colored_card(title, bullets, accent_color):
    card_data = [[""]]
    inner = []
    inner.append(Paragraph(title, styles["card_title"]))
    for b in bullets:
        inner.append(Paragraph(f"<bullet>&bull;</bullet> {b}", styles["card_body"]))

    card_data = [[inner]]
    t = Table(card_data, colWidths=[doc.width - 10])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), accent_color),
        ("ROUNDEDCORNERS", [8,8,8,8]),
        ("TOPPADDING", (0,0), (-1,-1), 12),
        ("BOTTOMPADDING", (0,0), (-1,-1), 12),
        ("LEFTPADDING", (0,0), (-1,-1), 14),
        ("RIGHTPADDING", (0,0), (-1,-1), 14),
    ]))
    story.append(t)
    story.append(Spacer(1, 8))

def add_feature_block(icon, title, description, bullets, sub_bullets=None):
    story.append(Paragraph(f"{icon}  {title}", styles["subsection"]))
    if description:
        story.append(Paragraph(description, styles["body"]))
    for b in bullets:
        story.append(Paragraph(f"<bullet>&bull;</bullet> {b}", styles["bullet"]))
    if sub_bullets:
        for sb in sub_bullets:
            story.append(Paragraph(f"<bullet>-</bullet> {sb}", styles["sub_bullet"]))
    story.append(Spacer(1, 4))

# ════════════════════════════════════════════════════════════
# PAGE 1 — COVER
# ════════════════════════════════════════════════════════════
story.append(Spacer(1, 1.8*inch))
story.append(Paragraph("PRIVACYSHIELD", styles["hero_title"]))
story.append(Paragraph("Digital Footprint &amp; Privacy Risk Auditor", styles["hero_sub"]))
story.append(Spacer(1, 6))
story.append(Paragraph('"See Everything. Control Everything. Own Your Digital Life."', styles["hero_tagline"]))
story.append(Spacer(1, 20))

# Platform badges
badge_data = [
    [Paragraph("WEB APP", styles["badge"]),
     Paragraph("MOBILE APP", styles["badge"]),
     Paragraph("AI-POWERED", styles["badge"]),
     Paragraph("BLOCKCHAIN", styles["badge"])]
]
badge_table = Table(badge_data, colWidths=[1.3*inch, 1.3*inch, 1.3*inch, 1.3*inch])
badge_table.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (0,0), ACCENT_BLUE),
    ("BACKGROUND", (1,0), (1,0), ACCENT_GREEN),
    ("BACKGROUND", (2,0), (2,0), ACCENT_PURPLE),
    ("BACKGROUND", (3,0), (3,0), ACCENT_ORANGE),
    ("ROUNDEDCORNERS", [6,6,6,6]),
    ("TOPPADDING", (0,0), (-1,-1), 8),
    ("BOTTOMPADDING", (0,0), (-1,-1), 8),
    ("LEFTPADDING", (0,0), (-1,-1), 6),
    ("RIGHTPADDING", (0,0), (-1,-1), 6),
    ("ALIGN", (0,0), (-1,-1), "CENTER"),
    ("VALIGN", (0,0), (-1,-1), "MIDDLE"),
]))
story.append(badge_table)
story.append(Spacer(1, 30))
story.append(Paragraph("CSI TSEC Hackathon 4.0  |  2026", styles["hero_sub"]))
story.append(Paragraph("Problem Statement: Digital Footprint &amp; Privacy Risk Auditor", styles["footer"]))

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 2 — PROBLEM + APPROACH
# ════════════════════════════════════════════════════════════
story.append(Paragraph("THE PROBLEM", styles["section_title"]))
story.append(Paragraph(
    "People have dozens of accounts, reused passwords, and apps with broad permissions — yet have <b>no idea how exposed they are</b>. "
    "Accounts are quietly linked through email recovery and SSO, so <b>one compromised account can open the door to many others</b>. "
    "Existing tools check a single password or breach but never show how everything connects or what to fix first.",
    styles["body"]
))
add_divider(ACCENT_BLUE)

story.append(Paragraph("OUR APPROACH", styles["section_title"]))
story.append(Paragraph(
    "PrivacyShield is a <b>cross-platform (Web + Mobile) AI-powered privacy command center</b> backed by <b>blockchain-verified audit trails</b>. "
    "It maps your entire digital footprint into an interactive graph, uses AI to score cascading risk across account chains, and stores every "
    "audit/fix action on-chain so your privacy posture is provably immutable and tamper-proof.",
    styles["body"]
))

add_colored_card("WHY AI + BLOCKCHAIN?", [
    "AI: Graph neural networks model cascading risk across interconnected accounts — not just isolated checks.",
    "AI: NLP scans privacy policies &amp; T&C changes in real-time, alerting you to hidden data-sharing clauses.",
    "AI: Predictive breach probability engine — knows which of YOUR accounts is most likely to be hit next.",
    "Blockchain: Every risk score, audit, and fix action is hashed on-chain — immutable proof of your privacy posture.",
    "Blockchain: Zero-Knowledge Proofs let you prove your security level to insurers/employers without revealing account details.",
    "Blockchain: Decentralized identity (DID) replaces centralized SSO — you own your login, not Google/Apple.",
], HexColor("#1E293B"))

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 3 — CORE FEATURES (REQUIREMENT 1-3)
# ════════════════════════════════════════════════════════════
story.append(Paragraph("CORE FEATURES", styles["section_title"]))
add_divider(ACCENT_PURPLE)

add_feature_block(
    "[1]", "Accounts &amp; Apps Inventory (Web + App)",
    "A unified vault to catalog every digital account, app permission, and connection — without storing real passwords.",
    [
        "<b>Smart Import:</b> Auto-detect accounts from email inbox scanning (OAuth read-only), browser extensions, and app permission APIs",
        "<b>Manual Add:</b> Add accounts with service name, email used, 2FA status, password-reuse group label, recovery methods",
        "<b>App Permission Scanner (Mobile):</b> Native integration with Android/iOS permission APIs to list every app's access (camera, location, contacts, mic, storage)",
        "<b>SSO &amp; Recovery Chain Mapping:</b> Map which accounts use Google/Apple/Facebook SSO, and which emails serve as recovery for others",
        "<b>Password Reuse Groups:</b> Label accounts sharing the same password (no real passwords stored) — see exactly how many doors one leaked password opens",
        "<b>Blockchain Anchor:</b> Hash of your full inventory stored on-chain as a timestamped snapshot — proves your audit state at any point in time",
    ]
)

add_feature_block(
    "[2]", "Exposure Mapping &amp; Risk Scoring (AI-Powered Core Challenge)",
    "The brain of PrivacyShield — a graph-based AI engine that models cascading risk across your entire digital network.",
    [
        "<b>Interactive Account Graph:</b> Visual force-directed graph showing every account as a node, with edges for SSO links, recovery chains, shared passwords, and data-sharing connections",
        "<b>Cascading Risk Engine (GNN):</b> Graph Neural Network propagates risk through connections — a weak email account that can reset 10 others gets a critical score even if it has 2FA",
        "<b>Breach History Integration:</b> Auto-check accounts against HaveIBeenPwned and breach databases; flag actively compromised credentials",
        "<b>Single Point of Failure Detection:</b> AI identifies \"keystone\" accounts — the one email/phone that if compromised unlocks everything",
        "<b>Risk Score Formula:</b> Composite score per account: breach history (30%) + permission scope (20%) + password reuse (20%) + missing 2FA (15%) + cascading impact (15%)",
        "<b>Network-Wide Privacy Score:</b> Overall 0-100 score reflecting your entire digital footprint health, weighted by cascading dependencies",
    ]
)

add_feature_block(
    "[3]", "AI Fix Checklist &amp; Guided Remediation",
    "Not just alerts — actionable, prioritized steps ranked by how much overall risk each one removes.",
    [
        "<b>Priority-Ranked Actions:</b> AI ranks fixes by network-wide risk reduction — enabling 2FA on your primary Gmail might remove 40 points of cascading risk across 15 accounts",
        "<b>One-Tap Fix Links:</b> Deep-links to each service's security settings page (2FA setup, password change, permission revoke, account deletion)",
        "<b>Guided Walkthroughs:</b> Step-by-step visual guides for non-technical users (e.g., 'How to enable 2FA on Instagram')",
        "<b>Fix Impact Preview:</b> Before and after risk score simulation — see how much your score improves BEFORE doing the fix",
        "<b>Progress Tracking:</b> Checklist tracks completed vs. pending fixes with completion percentage and estimated time",
        "<b>Blockchain Fix Receipt:</b> Each completed fix action is hashed on-chain — immutable proof you took the action at that timestamp",
    ]
)

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 4 — CORE FEATURES (REQUIREMENT 4-6)
# ════════════════════════════════════════════════════════════
story.append(Paragraph("CORE FEATURES (CONTINUED)", styles["section_title"]))
add_divider(ACCENT_PURPLE)

add_feature_block(
    "[4]", "Search, Filters &amp; Exploration",
    "Navigate your digital footprint with powerful search and drill-down.",
    [
        "<b>Global Search:</b> Instant search across accounts, services, permissions, risk levels, and fix actions",
        "<b>Smart Filters:</b> Filter by risk level (Critical/High/Medium/Low), service type (Social/Finance/Email/Cloud), 2FA status, data shared, last activity date",
        "<b>Graph Filters:</b> Highlight specific connection types on the graph — show only SSO chains, only password-reuse clusters, or only recovery links",
        "<b>Timeline View:</b> See when each account was added, last audited, and breach history chronologically",
    ]
)

add_feature_block(
    "[5]", "Reminders, Breach Alerts &amp; Continuous Monitoring",
    "Always-on vigilance — never be blindsided by a breach again.",
    [
        "<b>Real-Time Breach Monitor:</b> Continuous background scanning against breach databases; instant push notification (web + mobile) when your data appears in a new breach",
        "<b>Cascade Alert:</b> When one service is breached, AI instantly maps which linked accounts are now at risk and generates an emergency fix checklist",
        "<b>Periodic Review Reminders:</b> Scheduled prompts (weekly/monthly) to review permissions, update passwords, and re-audit",
        "<b>Dark Web Scanning (AI):</b> NLP-powered scanning of dark web paste sites and forums for your email/username mentions",
        "<b>Smart Notification Priority:</b> AI categorizes alerts as Critical (act now), Warning (act this week), Info (awareness only) — no alert fatigue",
    ]
)

add_feature_block(
    "[6]", "Privacy Dashboard — The Command Center",
    "One view. Full visibility. Every metric that matters.",
    [
        "<b>Overall Privacy Score:</b> Large 0-100 gauge with trend arrow showing improvement/decline over time",
        "<b>Risk Heatmap:</b> Accounts colored by risk level on the interactive graph — red clusters scream for attention",
        "<b>Single Points of Failure:</b> Top 3 keystone accounts highlighted with their cascading impact radius",
        "<b>Fix Progress:</b> Completion ring showing % of recommended fixes done, with estimated time remaining",
        "<b>Connection Graph Mini-Map:</b> Zoomable mini-view of your full account network with edge coloring by connection type",
        "<b>Improvement Timeline:</b> Historical chart showing your privacy score over weeks/months as you complete fixes",
        "<b>Breach Exposure Summary:</b> Count of breaches affecting your accounts, total records exposed, and remediation status",
    ]
)

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 5 — AI FEATURES DEEP DIVE
# ════════════════════════════════════════════════════════════
story.append(Paragraph("AI FEATURES DEEP DIVE", styles["section_title"]))
add_divider(ACCENT_CYAN)

add_feature_block(
    "[AI-1]", "Privacy Policy Watchdog (NLP Engine)",
    "AI reads the fine print so you don't have to.",
    [
        "<b>Auto-Scan T&amp;Cs:</b> NLP model ingests Terms of Service and Privacy Policies of your connected services",
        "<b>Plain-English Summaries:</b> Converts legalese into simple risk summaries — 'This app shares your location data with 47 third-party advertisers'",
        "<b>Change Detection:</b> Monitors policy updates and alerts you when a service quietly adds new data-sharing clauses",
        "<b>Risk Flags:</b> Auto-flags clauses about data selling, indefinite retention, cross-border transfers, and government disclosure",
    ]
)

add_feature_block(
    "[AI-2]", "Predictive Breach Probability",
    "Which of YOUR accounts is most likely to be breached next?",
    [
        "<b>Historical Pattern Analysis:</b> ML model trained on breach frequency, company size, sector vulnerability patterns, and security posture signals",
        "<b>Per-Account Probability:</b> Each account gets a predicted breach probability score for the next 6 months",
        "<b>Proactive Hardening:</b> AI recommends preemptive actions for high-probability targets BEFORE a breach occurs",
        "<b>Sector Risk Trends:</b> Dashboard showing which sectors (healthcare, fintech, social media) are trending toward higher breach rates",
    ]
)

add_feature_block(
    "[AI-3]", "AI Chat Assistant — PrivacyBot",
    "Ask anything about your digital security in natural language.",
    [
        "<b>Natural Language Queries:</b> 'Which of my accounts are most at risk?' / 'What happens if my Gmail gets hacked?' / 'How do I delete my old Facebook?'",
        "<b>Scenario Simulation:</b> 'What if my phone is stolen?' — AI simulates the attack chain through your account graph and shows exposure",
        "<b>Personalized Advice:</b> Context-aware recommendations based on YOUR specific account network, not generic tips",
        "<b>Voice Input (Mobile):</b> Ask questions via voice on the mobile app for hands-free security checks",
    ]
)

add_feature_block(
    "[AI-4]", "Smart Permission Advisor",
    "AI analyzes whether each app actually NEEDS the permissions it has.",
    [
        "<b>Permission vs. Usage Analysis:</b> Cross-reference granted permissions with app category — a calculator app with microphone access gets flagged",
        "<b>Risk-per-Permission Score:</b> Quantify how much risk each permission adds (location + contacts + camera = high surveillance potential)",
        "<b>Bulk Revoke Suggestions:</b> One-tap list of permissions you can safely revoke without breaking app functionality",
        "<b>App Alternatives:</b> AI suggests privacy-respecting alternatives for high-risk apps (e.g., Signal instead of a messaging app with poor privacy)",
    ]
)

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 6 — BLOCKCHAIN FEATURES DEEP DIVE
# ════════════════════════════════════════════════════════════
story.append(Paragraph("BLOCKCHAIN FEATURES DEEP DIVE", styles["section_title"]))
add_divider(ACCENT_ORANGE)

add_feature_block(
    "[BC-1]", "Immutable Audit Trail",
    "Every privacy action you take is permanently and verifiably recorded.",
    [
        "<b>On-Chain Hashing:</b> SHA-256 hash of every audit snapshot, risk score change, and fix action stored on Polygon/Ethereum L2",
        "<b>Timestamped Proof:</b> Prove to any third party (insurer, employer, regulator) exactly when you audited your accounts and what actions you took",
        "<b>Tamper-Proof History:</b> No one — not even you — can retroactively alter your privacy audit history",
        "<b>Gas-Efficient:</b> Batch multiple actions into Merkle tree roots — one on-chain transaction covers hundreds of actions",
    ]
)

add_feature_block(
    "[BC-2]", "Zero-Knowledge Privacy Proofs (ZKP)",
    "Prove your security level WITHOUT revealing your account details.",
    [
        "<b>ZK-SNARK Certificates:</b> Generate a cryptographic proof that your privacy score is above a threshold (e.g., &gt;80) without revealing which accounts you have or their individual scores",
        "<b>Use Cases:</b> Share ZKP with cyber insurance providers for lower premiums, with employers for compliance, or with platforms for trust verification",
        "<b>Selective Disclosure:</b> Choose exactly what to prove — 'I have 2FA on all financial accounts' without listing which financial accounts you use",
        "<b>Verifiable On-Chain:</b> Any verifier can check the proof against the blockchain without accessing your data",
    ]
)

add_feature_block(
    "[BC-3]", "Decentralized Identity (DID) Integration",
    "Own your identity — stop depending on Google/Apple/Facebook for login.",
    [
        "<b>Self-Sovereign Identity:</b> Create a DID (W3C standard) anchored on blockchain — your login credential that no company can revoke",
        "<b>Replace SSO Dependency:</b> Gradually migrate from Google SSO to DID-based authentication, eliminating single-provider failure",
        "<b>Portable Reputation:</b> Your privacy score and audit history travel with your DID across platforms",
        "<b>Wallet Integration:</b> MetaMask / WalletConnect for blockchain interactions; no crypto knowledge required for basic features",
    ]
)

add_feature_block(
    "[BC-4]", "Decentralized Breach Reporting (DAO)",
    "Community-powered breach intelligence that can't be censored or delayed.",
    [
        "<b>Breach Report DAO:</b> Anyone can submit a breach report to the decentralized network; community validators verify before alerting users",
        "<b>Incentivized Reporting:</b> Token rewards for verified breach reports — security researchers earn tokens for early disclosures",
        "<b>Faster Than Official:</b> Community-reported breaches often surface days/weeks before companies officially disclose",
        "<b>Censorship-Resistant:</b> No single entity can suppress or delay breach notifications",
    ]
)

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 7 — CRAZY EXTRA FEATURES
# ════════════════════════════════════════════════════════════
story.append(Paragraph("CRAZY EXTRA FEATURES", styles["section_title"]))
story.append(Paragraph(
    "Beyond the requirements — features that make PrivacyShield unforgettable at the hackathon.",
    styles["body"]
))
add_divider(ACCENT_PINK)

add_feature_block(
    "[X1]", "\"HACK ME\" Attack Simulator",
    "Simulate a real attack on YOUR account network to see exactly what an attacker could reach.",
    [
        "<b>Choose Attack Entry Point:</b> Pick any account and simulate it being compromised",
        "<b>Animated Attack Chain:</b> Watch the attack propagate through your graph in real-time — SSO links, recovery chains, password reuse — each hop lights up red",
        "<b>Damage Report:</b> After simulation, see total accounts reachable, data exposed, and financial accounts at risk",
        "<b>Before/After:</b> Run the simulation again AFTER applying recommended fixes to see the attack chain shrink",
    ]
)

add_feature_block(
    "[X2]", "Privacy Score NFT Badge",
    "Mint your privacy score as a dynamic, on-chain NFT that updates as your score changes.",
    [
        "<b>Dynamic NFT:</b> SVG-based NFT that visually changes color/design based on your current privacy score (green shield = strong, red skull = weak)",
        "<b>Flex Your Security:</b> Display on social profiles, resumes, or portfolios — verifiable proof of your digital hygiene",
        "<b>Leaderboard:</b> Anonymous global leaderboard of privacy scores — compete to be the most secure",
        "<b>Achievement Badges:</b> Earn special NFTs for milestones — '2FA Everywhere', 'Zero Reused Passwords', 'Dark Web Clean'",
    ]
)

add_feature_block(
    "[X3]", "\"Digital Death Switch\" — Emergency Lockdown",
    "One button to lock down your entire digital life if your phone/laptop is stolen or you suspect a breach.",
    [
        "<b>Panic Button:</b> Single tap triggers pre-configured emergency actions across all connected accounts",
        "<b>Auto-Actions:</b> Revoke all active sessions, trigger password resets on critical accounts, enable lockout on financial services",
        "<b>Trusted Contact Alert:</b> Auto-notify designated trusted contacts with instructions if you're unreachable",
        "<b>Recovery Plan:</b> Pre-built recovery sequence to regain access in the right order after lockdown",
    ]
)

add_feature_block(
    "[X4]", "AI \"Digital Twin\" Risk Simulation",
    "AI creates a virtual twin of your digital identity to stress-test it against emerging threats.",
    [
        "<b>Synthetic Threat Scenarios:</b> AI generates novel attack scenarios (SIM swap + social engineering + credential stuffing combo attacks)",
        "<b>Vulnerability Discovery:</b> Finds attack paths you'd never think of — 'Your Spotify recovery email is the same as your bank, and Spotify was breached 3 times'",
        "<b>Continuous Red-Teaming:</b> Background AI agent periodically probes your digital twin for new weaknesses as your account network changes",
    ]
)

add_feature_block(
    "[X5]", "Family/Team Privacy Shield",
    "Protect your entire family or team's digital footprint from one dashboard.",
    [
        "<b>Family Network View:</b> See how family members' accounts interconnect (shared Netflix, family iCloud, etc.)",
        "<b>Weakest Link Alert:</b> If one family member's security is weak, AI shows how it could compromise others",
        "<b>Parental Privacy Controls:</b> Monitor and manage children's app permissions and account exposure",
        "<b>Team Compliance (Enterprise):</b> For companies — ensure all employees meet security baselines, with ZKP-verified compliance reports",
    ]
)

add_feature_block(
    "[X6]", "Data Broker Opt-Out Automation",
    "AI finds where your data is being sold and auto-submits removal requests.",
    [
        "<b>Broker Discovery:</b> AI scans known data broker databases (Spokeo, Whitepages, BeenVerified, etc.) for your personal info listings",
        "<b>Auto Opt-Out:</b> Automatically fills and submits opt-out/removal request forms on your behalf",
        "<b>Verification Follow-Up:</b> Re-checks after 30/60/90 days to confirm your data was actually removed",
        "<b>New Listing Alerts:</b> Continuous monitoring for new appearances of your data on broker sites",
    ]
)

add_feature_block(
    "[X7]", "AR Privacy Scanner (Mobile Exclusive)",
    "Point your camera at any app on your screen to see its privacy risk overlay in augmented reality.",
    [
        "<b>Visual Risk Overlay:</b> Hold phone over laptop screen showing apps — AR overlay shows risk score, permissions, and breach status for each app icon",
        "<b>QR Privacy Check:</b> Scan any app's QR code to instantly see its privacy analysis before installing",
        "<b>Physical Device Audit:</b> Point at smart home devices (Alexa, Ring, etc.) to see what data they collect and their risk score",
    ]
)

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 8 — TECH STACK + ARCHITECTURE
# ════════════════════════════════════════════════════════════
story.append(Paragraph("TECH STACK &amp; ARCHITECTURE", styles["section_title"]))
add_divider(ACCENT_GREEN)

tech_stack = [
    ("FRONTEND (WEB)", "React.js / Next.js + TailwindCSS + D3.js/Cytoscape.js for interactive graph visualization + Framer Motion for attack simulation animations"),
    ("MOBILE APP", "React Native / Flutter — cross-platform iOS &amp; Android with native permission scanner APIs + biometric auth (FaceID/Fingerprint)"),
    ("BACKEND", "Node.js (Express/Fastify) or Python (FastAPI) — RESTful API + WebSocket for real-time breach alerts + Redis for caching"),
    ("AI / ML ENGINE", "Python — PyTorch Geometric for Graph Neural Networks (cascading risk) + HuggingFace Transformers for NLP policy analysis + scikit-learn for breach prediction + LangChain/Claude API for PrivacyBot chat"),
    ("DATABASE", "PostgreSQL (accounts, users) + Neo4j (account relationship graph) + MongoDB (unstructured breach data, policy documents)"),
    ("BLOCKCHAIN", "Polygon (L2 Ethereum) for gas-efficient on-chain hashing + Solidity smart contracts for audit trail + ZK-SNARKs (circom/snarkjs) for privacy proofs + IPFS for decentralized data storage"),
    ("BREACH INTELLIGENCE", "HaveIBeenPwned API + custom dark web scraper (Tor-based) + community DAO breach reporting"),
    ("AUTH &amp; SECURITY", "OAuth 2.0 for inbox scanning + AES-256 encryption at rest + end-to-end encryption + DID/Verifiable Credentials (W3C standard)"),
    ("INFRA &amp; DEVOPS", "Docker + Kubernetes + AWS/GCP + CI/CD (GitHub Actions) + Grafana/Prometheus monitoring"),
]

for label, body in tech_stack:
    story.append(Paragraph(label, styles["tech_label"]))
    story.append(Paragraph(body, styles["tech_body"]))

story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# PAGE 9 — WEB VS APP FEATURE MATRIX
# ════════════════════════════════════════════════════════════
story.append(Paragraph("WEB vs. MOBILE APP — FEATURE MATRIX", styles["section_title"]))
add_divider(ACCENT_BLUE)

matrix_data = [
    ["Feature", "Web App", "Mobile App"],
    ["Account Inventory & Import", "Yes", "Yes"],
    ["Interactive Account Graph", "Full (D3.js)", "Simplified"],
    ["App Permission Scanner", "Browser Ext Only", "Native API"],
    ["AI Risk Scoring Engine", "Yes", "Yes"],
    ["PrivacyBot Chat", "Yes", "Yes + Voice"],
    ["Breach Alerts", "Browser Push", "Native Push"],
    ["Attack Simulator", "Full Animated", "Simplified"],
    ["Privacy Dashboard", "Full Desktop", "Mobile-Optimized"],
    ["AR Privacy Scanner", "No", "Yes (Exclusive)"],
    ["Panic Button / Lockdown", "Yes", "Yes + Widget"],
    ["Biometric Auth", "WebAuthn", "FaceID / Fingerprint"],
    ["NFT Badge Minting", "Yes", "Yes"],
    ["ZKP Certificate", "Yes", "Yes"],
    ["Offline Mode", "No", "Partial (cached data)"],
    ["Dark Web Scan", "Yes", "Yes"],
    ["Data Broker Opt-Out", "Yes", "Yes"],
    ["Family Shield", "Yes", "Yes"],
]

t = Table(matrix_data, colWidths=[2.6*inch, 1.5*inch, 1.5*inch])
t.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (-1,0), ACCENT_BLUE),
    ("TEXTCOLOR", (0,0), (-1,0), white),
    ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
    ("FONTSIZE", (0,0), (-1,0), 10),
    ("FONTNAME", (0,1), (-1,-1), "Helvetica"),
    ("FONTSIZE", (0,1), (-1,-1), 9),
    ("BACKGROUND", (0,1), (-1,-1), LIGHT_BG),
    ("ROWBACKGROUNDS", (0,1), (-1,-1), [LIGHT_BG, white]),
    ("GRID", (0,0), (-1,-1), 0.5, BORDER),
    ("TOPPADDING", (0,0), (-1,-1), 6),
    ("BOTTOMPADDING", (0,0), (-1,-1), 6),
    ("LEFTPADDING", (0,0), (-1,-1), 8),
    ("ALIGN", (1,0), (-1,-1), "CENTER"),
    ("VALIGN", (0,0), (-1,-1), "MIDDLE"),
]))
story.append(t)

story.append(Spacer(1, 20))
story.append(Paragraph("UNIQUE SELLING POINTS", styles["section_title"]))
add_divider(ACCENT_PINK)

usps = [
    "<b>Not just a checker — a network analyzer:</b> Unlike HaveIBeenPwned or password managers, we model cascading risk across your ENTIRE account graph",
    "<b>Blockchain-verified trust:</b> Your privacy posture is provably immutable — no one can fake or backdate a security audit",
    "<b>AI that thinks like a hacker:</b> Attack simulator and digital twin red-team YOUR accounts, not generic scenarios",
    "<b>Zero-Knowledge compliance:</b> Prove your security level without revealing anything — game-changer for insurance and enterprise",
    "<b>Cross-platform parity:</b> Full experience on web AND mobile, with mobile-exclusive features (AR scanner, native permissions, panic widget)",
    "<b>Community-powered intelligence:</b> Decentralized breach reporting DAO — faster, uncensorable, incentivized",
]
for u in usps:
    story.append(Paragraph(f"<bullet>&bull;</bullet> {u}", styles["bullet"]))

story.append(Spacer(1, 20))
story.append(Paragraph("Built with passion for CSI TSEC Hackathon 4.0 — 2026", styles["footer"]))

# ── Build PDF ──
doc.build(story)
print(f"PDF generated: {output_path}")
