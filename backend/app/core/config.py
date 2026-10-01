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
    hibp_mode: str = "live"
    xon_mode: str = "live"
    gmail_client_id: str = ""
    gmail_client_secret: str = ""
    gmail_redirect_uri: str = ""
    monitor_interval_minutes: int = 360
    polygon_rpc_url: str = "https://rpc-amoy.polygon.technology"
    polygon_private_key: str = ""
    polygon_explorer_tx_url: str = "https://amoy.polygonscan.com/tx/"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-flash-latest"
    gemini_fallback_model: str = "gemini-2.5-flash"
    voyage_api_key: str = ""
    voyage_model: str = "voyage-3.5"

    model_config = {"env_file": ".env", "extra": "ignore", "env_ignore_empty": True}


@lru_cache
def get_settings() -> Settings:
    return Settings()
