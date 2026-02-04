"""Integrations service configuration."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class IntegrationsSettings(BaseSettings):
    """Integrations service settings."""

    host: str = Field(default="0.0.0.0", description="Server host")
    port: int = Field(default=8001, description="Server port")
    debug: bool = Field(default=False, description="Debug mode")

    # App Store Connect Webhook
    appstore_webhook_secret: str = Field(
        default="",
        description="HMAC secret for verifying App Store Connect webhook signatures",
    )
    appstore_telegram_bot_token: str = Field(
        default="",
        description="Telegram bot token for App Store webhook notifications",
    )
    appstore_telegram_chat_id: str = Field(
        default="",
        description="Telegram chat ID for App Store webhook notifications",
    )
    appstore_telegram_thread_id: int | None = Field(
        default=None,
        description="Telegram thread/topic ID for App Store webhook notifications",
    )

    # Sentry Webhook
    sentry_webhook_telegram_bot_token: str = Field(
        default="",
        description="Telegram bot token for Sentry webhook notifications",
    )
    sentry_webhook_telegram_chat_id: str = Field(
        default="",
        description="Telegram chat ID for Sentry webhook notifications",
    )
    sentry_webhook_telegram_thread_id: int | None = Field(
        default=None,
        description="Telegram thread/topic ID for Sentry webhook notifications",
    )

    # OpenTelemetry
    otel_enabled: bool = Field(default=True, description="Enable OpenTelemetry")
    otel_service_name: str = Field(
        default="makefeed-integrations",
        description="OTEL service name",
    )
    otel_deployment_environment: str = Field(
        default="development",
        description="Deployment environment",
    )
    otel_exporter_otlp_endpoint: str = Field(
        default="http://localhost:4317",
        description="OTLP exporter endpoint",
    )

    # Sentry
    sentry_enabled: bool = Field(
        default=False, description="Enable Sentry error tracking"
    )
    sentry_dsn: str = Field(default="", description="Sentry DSN")
    sentry_environment: str = Field(
        default="production", description="Sentry environment"
    )
    sentry_traces_sample_rate: float = Field(
        default=0.0, description="Sentry traces sample rate"
    )
    sentry_send_default_pii: bool = Field(
        default=False, description="Send default PII to Sentry"
    )

    # Proxy
    proxy_url: str = Field(default="", description="Proxy URL for Sentry")
    proxy_username: str = Field(default="", description="Proxy username")
    proxy_password: str = Field(default="", description="Proxy password")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = IntegrationsSettings()
