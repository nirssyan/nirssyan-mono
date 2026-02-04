"""Configuration for makefeed-agents service."""

from pydantic import Field
from pydantic_settings import BaseSettings


class AgentsSettings(BaseSettings):
    """Settings for makefeed-agents service."""

    # NATS settings
    nats_url: str = "nats://nats:4222"

    # CRITICAL: PostgreSQL max_connections=100, shared across 8 services + Supabase
    database_url: str = Field(default="", description="PostgreSQL database URL")
    database_pool_size: int = Field(default=1, description="Connection pool size")
    database_max_overflow: int = Field(
        default=2, description="Max overflow connections"
    )
    database_pool_recycle: int = Field(
        default=300, description="Connection recycle time"
    )

    # AI/LLM settings (global defaults)
    ai_api_key: str = Field(
        default="",
        description="API key for AI provider",
    )
    ai_base_url: str = Field(
        default="",
        description="Base URL for AI provider",
    )
    ai_model: str = "meta-llama/llama-3.1-8b-instruct"
    llm_concurrent_requests: int = Field(
        default=20,
        description="Max concurrent LLM API requests",
    )
    llm_request_timeout: float = Field(
        default=30.0,
        description="Timeout for single LLM request in seconds",
    )
    unseen_summary_timeout: float = Field(
        default=90.0,
        description="Timeout for unseen_summary agent (longer due to complex prompt)",
    )

    # Per-agent model configuration (fallback to ai_model if not set)
    chat_message_model: str = "meta-llama/llama-3.1-8b-instruct"
    feed_filter_model: str = "mimo-v2-flash"
    feed_summary_model: str = "gpt-5.1-codex"
    post_title_model: str = "meta-llama/llama-3.1-8b-instruct"
    feed_title_model: str = "meta-llama/llama-3.1-8b-instruct"
    feed_description_model: str = "meta-llama/llama-3.1-8b-instruct"
    feed_tags_model: str = "meta-llama/llama-3.1-8b-instruct"
    feed_comment_model: str = "meta-llama/llama-3.1-8b-instruct"
    view_generator_model: str = "mimo-v2-flash"
    view_prompt_transformer_model: str = "google/gemini-2.5-flash-lite-preview-09-2025"
    unseen_summary_model: str = "mimo-v2-flash"

    # Per-agent API configuration (fallback to global ai_api_key/ai_base_url if empty)
    chat_message_api_key: str = ""
    chat_message_base_url: str = ""
    feed_filter_api_key: str = ""
    feed_filter_base_url: str = ""
    feed_summary_api_key: str = ""
    feed_summary_base_url: str = ""
    feed_tags_api_key: str = ""
    feed_tags_base_url: str = ""
    feed_title_api_key: str = ""
    feed_title_base_url: str = ""
    feed_description_api_key: str = ""
    feed_description_base_url: str = ""
    post_title_api_key: str = ""
    post_title_base_url: str = ""
    view_generator_api_key: str = ""
    view_generator_base_url: str = ""
    view_prompt_transformer_api_key: str = ""
    view_prompt_transformer_base_url: str = ""
    unseen_summary_api_key: str = ""
    unseen_summary_base_url: str = ""

    # OpenTelemetry settings
    otel_enabled: bool = True
    otel_logs_enabled: bool = Field(
        default=False,
        description="Enable OTLP logs export",
    )
    otel_service_name: str = "makefeed-agents"
    otel_exporter_otlp_endpoint: str = "http://otel-collector:4317"
    otel_exporter_otlp_protocol: str = "grpc"
    otel_exporter_otlp_insecure: bool = True
    otel_prometheus_port: int = Field(
        default=9464,
        description="Port for Prometheus metrics HTTP server",
    )
    otel_deployment_environment: str = "production"
    otel_sampling_rate: float = 1.0
    otel_trace_httpx_enabled: bool = False
    otel_trace_sql_enabled: bool = False

    # Sentry settings
    sentry_dsn: str = ""
    sentry_enabled: bool = False
    sentry_environment: str = ""
    sentry_traces_sample_rate: float = 0.0
    sentry_send_default_pii: bool = False

    # Proxy settings (for Sentry)
    proxy_url: str = ""
    proxy_username: str = ""
    proxy_password: str = ""

    # Debug settings
    debug: bool = False

    model_config = {"env_prefix": "", "case_sensitive": False, "extra": "ignore"}


settings = AgentsSettings()
