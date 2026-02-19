import re

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    api_base_url: str = "http://app-api-go:8080"
    internal_service_token: str = ""
    openrouter_api_key: str = ""
    llm_model: str = "anthropic/claude-haiku-4.5"
    host: str = "0.0.0.0"
    port: int = 7777
    database_url: str = ""
    debug: bool = False

    model_config = {"env_prefix": ""}

    @property
    def agno_database_url(self) -> str:
        if not self.database_url:
            return ""
        return re.sub(r"^postgres(ql)?(\+\w+)?://", "postgresql+psycopg://", self.database_url)


settings = Settings()
