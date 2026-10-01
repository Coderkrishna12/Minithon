from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Float, JSON, func
from sqlalchemy.orm import relationship
from app.db.base import Base


class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    service_name = Column(String(200), nullable=False)
    service_url = Column(String(500))
    email_used = Column(String(255))
    username_used = Column(String(200))
    category = Column(String(50))  # social, finance, email, cloud, shopping, gaming, etc.
    # None means the user/import has not established the account's 2FA state.
    has_2fa = Column(Boolean, default=None, nullable=True)
    password_group = Column(String(100))  # label for password reuse group
    login_method = Column(String(50), default="unknown")  # unknown until discovered/confirmed
    twofa_method = Column(String(30), nullable=True)
    added_via = Column(String(40), default="manual", nullable=False)
    import_confidence = Column(Float, nullable=True)
    evidence_source = Column(String(100), nullable=True)
    recovery_email = Column(String(255))
    recovery_phone = Column(String(50))
    permissions = Column(JSON, default=list)  # ["location", "contacts", "camera", ...]
    risk_score = Column(Float, default=0.0)
    risk_components = Column(JSON, default=dict)
    breach_count = Column(Integer, default=0)
    last_breach_date = Column(DateTime(timezone=True))
    is_active = Column(Boolean, default=True)
    notes = Column(String(1000))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="accounts")
    connections_from = relationship("AccountConnection", foreign_keys="AccountConnection.from_account_id", back_populates="from_account", cascade="all, delete-orphan")
    connections_to = relationship("AccountConnection", foreign_keys="AccountConnection.to_account_id", back_populates="to_account", cascade="all, delete-orphan")


class AccountConnection(Base):
    __tablename__ = "account_connections"

    id = Column(Integer, primary_key=True, index=True)
    from_account_id = Column(Integer, ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False)
    to_account_id = Column(Integer, ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False)
    connection_type = Column(String(50), nullable=False)  # sso, recovery_email, password_reuse, data_sharing
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    from_account = relationship("Account", foreign_keys=[from_account_id], back_populates="connections_from")
    to_account = relationship("Account", foreign_keys=[to_account_id], back_populates="connections_to")


class BreachRecord(Base):
    __tablename__ = "breach_records"

    id = Column(Integer, primary_key=True, index=True)
    account_id = Column(Integer, ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False)
    breach_name = Column(String(300), nullable=False)
    breach_date = Column(DateTime(timezone=True))
    data_exposed = Column(JSON, default=list)  # ["email", "password", "phone", ...]
    source = Column(String(100))  # hibp, dao, manual
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ChainAnchor(Base):
    __tablename__ = "chain_anchors"

    id = Column(Integer, primary_key=True, index=True)
    audit_log_id = Column(Integer, ForeignKey("audit_logs.id", ondelete="CASCADE"), nullable=False, unique=True)
    network_tx_hash = Column(String(100), nullable=False)
    chain_id = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class RagChunk(Base):
    __tablename__ = "rag_chunks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)  # NULL = shared corpus
    source_type = Column(String(50), nullable=False, index=True)
    source_id = Column(String(300), nullable=False)
    source_hash = Column(String(64), nullable=False)
    chunk_no = Column(Integer, nullable=False)
    title = Column(String(300), nullable=False)
    text = Column(String, nullable=False)
    url = Column(String(500))
    embedding = Column(JSON)
    embedding_model = Column(String(100))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class FixAction(Base):
    __tablename__ = "fix_actions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    account_id = Column(Integer, ForeignKey("accounts.id", ondelete="CASCADE"))
    action_type = Column(String(100), nullable=False)  # enable_2fa, change_password, revoke_permission, delete_account
    description = Column(String(500))
    priority = Column(Integer, default=0)  # higher = more urgent
    risk_reduction = Column(Float, default=0.0)
    status = Column(String(20), default="pending")  # pending, completed, skipped
    blockchain_tx_hash = Column(String(100))
    completed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    action = Column(String(100), nullable=False)
    details = Column(String(1000))
    data_hash = Column(String(64))
    blockchain_tx_hash = Column(String(100))
    blockchain_block = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(200), nullable=False)
    message = Column(String(1000), nullable=False)
    severity = Column(String(20), default="info")  # critical, warning, info
    is_read = Column(Boolean, default=False)
    related_account_id = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class NFTBadge(Base):
    __tablename__ = "nft_badges"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    badge_type = Column(String(100), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(String(500))
    score_at_mint = Column(Integer)
    token_id = Column(String(100))
    tx_hash = Column(String(100))
    metadata_uri = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ScoreHistory(Base):
    __tablename__ = "score_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    privacy_score = Column(Integer, nullable=False)
    total_accounts = Column(Integer, default=0)
    accounts_at_risk = Column(Integer, default=0)
    breaches_total = Column(Integer, default=0)
    event_type = Column(String(100))
    event_description = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class FamilyGroup(Base):
    __tablename__ = "family_groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    group_type = Column(String(50), default="family")
    invite_code = Column(String(20), unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class FamilyMember(Base):
    __tablename__ = "family_members"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("family_groups.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(50), default="member")  # owner, guardian, member
    # What the rest of the group may see: "summary" (score and counts) or "detailed" (risky accounts too).
    share_level = Column(String(20), default="summary", nullable=False)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())


class DIDIdentity(Base):
    __tablename__ = "did_identities"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    did_string = Column(String(500), unique=True, nullable=False)
    public_key = Column(String(500), nullable=False)
    verification_method = Column(String(200))
    credentials = Column(JSON, default=list)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DAOProposal(Base):
    __tablename__ = "dao_proposals"

    id = Column(Integer, primary_key=True, index=True)
    author_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(300), nullable=False)
    description = Column(String(2000), nullable=False)
    service_name = Column(String(200))
    breach_date = Column(String(50))
    data_types_affected = Column(JSON, default=list)
    evidence_url = Column(String(500))
    status = Column(String(50), default="active")
    votes_for = Column(Integer, default=0)
    votes_against = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DAOVote(Base):
    __tablename__ = "dao_votes"

    id = Column(Integer, primary_key=True, index=True)
    proposal_id = Column(Integer, ForeignKey("dao_proposals.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    vote = Column(String(10), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ReviewReminder(Base):
    __tablename__ = "review_reminders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reminder_type = Column(String(100), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(String(500))
    frequency_days = Column(Integer, default=30)
    is_active = Column(Boolean, default=True)
    last_triggered = Column(DateTime(timezone=True))
    next_trigger = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DarkWebAlert(Base):
    __tablename__ = "dark_web_alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    alert_type = Column(String(100), nullable=False)
    source = Column(String(200))
    data_found = Column(String(500))
    severity = Column(String(20), default="warning")
    is_resolved = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class AttackSimulation(Base):
    """One 'Hack Me' run, kept so the user can compare before and after real fixes."""
    __tablename__ = "attack_simulations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    entry_account_id = Column(Integer, ForeignKey("accounts.id", ondelete="SET NULL"))
    entry_service = Column(String(200), nullable=False)
    accounts_reachable = Column(Integer, nullable=False)
    financial_at_risk = Column(Integer, nullable=False, default=0)
    damage_score = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ZkCredential(Base):
    """A signed Pedersen commitment to the user's score. The opening never leaves the server."""
    __tablename__ = "zk_credentials"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    commitment = Column(String(600), nullable=False)
    randomness = Column(String(600), nullable=False)
    score = Column(Integer, nullable=False)
    credential = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
