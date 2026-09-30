from pydantic_settings import BaseSettings
from functools import lru_cache
import os


class Settings(BaseSettings):
    app_name: str = "PrivacyShield API"
    debug: bool = True
    database_url: str = "sqlite+aiosqlite:///./privacyshield.db"
    secret_key: str = "dev-secret-key-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    hibp_api_key: str = ""
    polygon_rpc_url: str = "https://polygon-rpc.com"
    anthropic_api_key: str = ""
    contract_address: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
