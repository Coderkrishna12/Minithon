from pydantic import BaseModel
from datetime import datetime


class AccountCreate(BaseModel):
    service_name: str
    service_url: str | None = None
    email_used: str | None = None
    username_used: str | None = None
    category: str | None = None
    has_2fa: bool | None = None
    password_group: str | None = None
    login_method: str = "unknown"
    twofa_method: str | None = None
    added_via: str = "manual"
    import_confidence: float | None = None
    evidence_source: str | None = None
    recovery_email: str | None = None
    recovery_phone: str | None = None
    permissions: list[str] = []
    notes: str | None = None


class AccountUpdate(BaseModel):
    service_name: str | None = None
    service_url: str | None = None
    email_used: str | None = None
    username_used: str | None = None
    category: str | None = None
    has_2fa: bool | None = None
    password_group: str | None = None
    login_method: str | None = None
    twofa_method: str | None = None
    recovery_email: str | None = None
    recovery_phone: str | None = None
    permissions: list[str] | None = None
    notes: str | None = None


class AccountResponse(BaseModel):
    id: int
    service_name: str
    service_url: str | None
    email_used: str | None
    username_used: str | None
    category: str | None
    has_2fa: bool | None
    password_group: str | None
    login_method: str | None
    twofa_method: str | None = None
    added_via: str = "manual"
    import_confidence: float | None = None
    evidence_source: str | None = None
    recovery_email: str | None
    recovery_phone: str | None
    permissions: list[str]
    risk_score: float
    risk_components: dict = {}
    breach_count: int
    last_breach_date: datetime | None
    is_active: bool
    notes: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class ConnectionCreate(BaseModel):
    from_account_id: int
    to_account_id: int
    connection_type: str  # sso, recovery_email, password_reuse, data_sharing


class ConnectionResponse(BaseModel):
    id: int
    from_account_id: int
    to_account_id: int
    connection_type: str
    created_at: datetime

    model_config = {"from_attributes": True}


class FixActionResponse(BaseModel):
    id: int
    account_id: int | None
    action_type: str
    description: str | None
    priority: int
    risk_reduction: float
    status: str
    blockchain_tx_hash: str | None
    completed_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class DashboardResponse(BaseModel):
    privacy_score: int
    total_accounts: int
    accounts_at_risk: int
    breaches_found: int
    fixes_completed: int
    fixes_pending: int
    single_points_of_failure: list[AccountResponse]
    risk_distribution: dict[str, int]  # {"critical": 2, "high": 5, ...}
    category_breakdown: dict[str, int]
