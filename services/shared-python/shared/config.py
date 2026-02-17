"""Base configuration for all microservices."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class BaseServiceSettings(BaseSettings):
    """Base settings shared by all microservices."""

    # CRITICAL: PostgreSQL max_connections=100, shared across all services
    # Minimal pool to prevent connection exhaustion
    database_url: str = "postgresql+asyncpg://user:password@localhost/dbname"
    database_pool_size: int = 1
    database_max_overflow: int = 2
    database_pool_timeout: int = 30
    database_pool_recycle: int = 300  # Close stale connections after 5 minutes

    # NATS settings
    nats_url: str = Field(
        default="nats://nats:4222",
        description="NATS server URL for inter-service communication",
    )
    nats_enabled: bool = Field(
        default=True,
        description="Enable NATS messaging",
    )
    nats_connect_timeout: float = Field(
        default=10.0,
        description="NATS connection timeout in seconds",
    )
    nats_reconnect_time_wait: float = Field(
        default=2.0,
        description="Time to wait before reconnecting to NATS",
    )
    nats_max_reconnect_attempts: int = Field(
        default=60,
        description="Maximum number of reconnect attempts",
    )

    # OpenTelemetry settings
    otel_enabled: bool = True
    otel_service_name: str = "makefeed-service"
    otel_exporter_otlp_endpoint: str = "http://otel-collector:4317"
    otel_exporter_otlp_protocol: str = "grpc"
    otel_exporter_otlp_insecure: bool = True
    otel_deployment_environment: str = "production"
    otel_trace_sql_enabled: bool = True
    otel_sampling_rate: float = 1.0

    # Debug settings
    debug: bool = False

    # Sentry Error Tracking settings
    sentry_dsn: str = Field(
        default="",
        description="Sentry DSN for error tracking. Leave empty to disable.",
    )
    sentry_enabled: bool = Field(
        default=False,
        description="Enable/disable Sentry error tracking",
    )
    sentry_environment: str = Field(
        default="",
        description="Sentry environment (auto-detected from otel_deployment_environment if empty)",
    )
    sentry_traces_sample_rate: float = Field(
        default=0.0,
        description="Sentry traces sample rate (0.0 = disabled, using OpenTelemetry instead)",
    )
    sentry_send_default_pii: bool = Field(
        default=False,
        description="Send default PII to Sentry",
    )

    # HTTP Proxy settings (for external services like Sentry)
    proxy_url: str = Field(
        default="",
        description="HTTP/HTTPS proxy URL (e.g., https://proxy.example.com)",
    )
    proxy_username: str = Field(
        default="",
        description="Proxy authentication username",
    )
    proxy_password: str = Field(
        default="",
        description="Proxy authentication password",
    )

    @property
    def alembic_database_url(self) -> str:
        """Synchronous DATABASE_URL for Alembic (without +asyncpg)."""
        return self.database_url.replace("+asyncpg", "")

    model_config = SettingsConfigDict(
        env_file=[".env", "../.env", "../../.env"],
        env_file_encoding="utf-8",
        extra="allow",
    )
