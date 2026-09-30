import secrets
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "PrivacyShield API"
    debug: bool = True
    database_url: str = "sqlite+aiosqlite:///./privacyshield.db"
    # Without SECRET_KEY set, a random key is generated per process, so tokens reset on restart.
    secret_key: str = Field(default_factory=lambda: secrets.token_urlsafe(32))
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    hibp_api_key: str = ""
    hibp_rpm: int = 10
    polygon_rpc_url: str = "https://polygon-rpc.com"
    anthropic_api_key: str = ""
    contract_address: str = ""

    model_config = {"env_file": ".env", "extra": "ignore", "env_ignore_empty": True}


@lru_cache
def get_settings() -> Settings:
    return Settings()
