from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=Path(__file__).resolve().parents[2] / ".env", extra="ignore")
    database_url: str = "postgresql+psycopg://etsgo:etsgo@localhost:5432/etsgo"
    supabase_url: str = ""
    supabase_anon_key: str = ""
    encryption_key: str = ""
    # AI provider: "openai" or "anthropic". Empty selects the provider whose key is set.
    ai_provider: str = ""
    ai_model: str = ""
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    # "responses" (OpenAI Responses API) or "chat" (Chat Completions, for compatible gateways).
    openai_api_style: str = "responses"
    # Optional reasoning effort for reasoning models, e.g. "low". Empty sends nothing.
    ai_reasoning_effort: str = ""
    ai_timeout_seconds: int = 120
    daily_ai_limit: int = 20
    google_client_id: str = ""
    google_client_secret: str = ""
    public_url: str = "http://localhost:8000"
    # Development login is disabled by default and cannot run in production.
    environment: str = "production"
    dev_auth_secret: str = ""
    dev_trust_docker_gateway: bool = False
    busy_max_age_seconds: int = 300

    @property
    def resolved_ai_provider(self) -> str:
        provider = self.ai_provider.strip().lower()
        if provider:
            return provider
        if self.openai_api_key:
            return "openai"
        return "anthropic"


@lru_cache
def settings() -> Settings:
    return Settings()
