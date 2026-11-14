from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=Path(__file__).resolve().parents[2] / ".env", extra="ignore")
    database_url: str = "postgresql+psycopg://etsgo:etsgo@localhost:5432/etsgo"
    app_session_secret: str = ""
    encryption_key: str = ""
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    ai_provider: Literal["anthropic", "openai"] = "anthropic"
    ai_model: str = ""
    daily_ai_limit: int = 20
    google_client_id: str = ""
    google_client_secret: str = ""
    public_url: str = "http://localhost:8000"
    # Development login is disabled by default and cannot run in production.
    environment: str = "production"
    dev_auth_secret: str = ""
    dev_trust_docker_gateway: bool = False
    busy_max_age_seconds: int = 300


@lru_cache
def settings() -> Settings:
    return Settings()
