"""Sentry SDK initialization and configuration with proxy support.

This module provides a shared Sentry setup that can be used by all microservices.
Includes OpenTelemetry trace context injection for distributed tracing correlation.
"""

import base64
from typing import Any, Protocol

from .trace_context import get_current_span_id, get_current_trace_id


class SentrySettings(Protocol):
    """Protocol for settings object with Sentry configuration."""

    sentry_dsn: str
    sentry_enabled: bool
    sentry_environment: str
    sentry_traces_sample_rate: float
    sentry_send_default_pii: bool
    proxy_url: str
    proxy_username: str
    proxy_password: str
    otel_deployment_environment: str
    otel_service_name: str


def _build_proxy_headers(settings: SentrySettings) -> dict[str, str] | None:
    """Build proxy authentication headers if credentials are configured.

    Args:
        settings: Settings object with proxy configuration.

    Returns:
        Dictionary with Proxy-Authorization header, or None if no credentials.
    """
    if not settings.proxy_username or not settings.proxy_password:
        return None

    credentials = f"{settings.proxy_username}:{settings.proxy_password}"
    encoded = base64.b64encode(credentials.encode()).decode()
    return {"Proxy-Authorization": f"Basic {encoded}"}


IGNORED_EXCEPTION_TYPES = {
    "FileReferenceExpired",
}

IGNORED_MESSAGE_PATTERNS = [
    "Failed to export traces to",
    "Failed to export logs to",
    "Failed to export metrics to",
    "Transient error StatusCode.UNAVAILABLE encountered while exporting",
    "error exporting spans",
]


def _process_event(
    event: dict[str, Any], hint: dict[str, Any]
) -> dict[str, Any] | None:
    """Process Sentry event: scrub sensitive data and inject trace context.

    This function:
    1. Filters out expected/handled exceptions (FileReferenceExpired, etc.)
    2. Removes values for keys containing sensitive patterns (api_key, password, etc.)
    3. Injects OpenTelemetry trace_id and span_id for distributed tracing correlation

    Returns:
        Processed event dict, or None to drop the event.
    """
    exc_info = hint.get("exc_info")
    if exc_info:
        exc_type = exc_info[0]
        if exc_type and exc_type.__name__ in IGNORED_EXCEPTION_TYPES:
            return None

    exception_values = event.get("exception", {}).get("values", [])
    for exc_value in exception_values:
        exc_type_name = exc_value.get("type", "")
        if exc_type_name in IGNORED_EXCEPTION_TYPES:
            return None

    if event.get("logger") == "logging":
        message = event.get("message", "") or event.get("logentry", {}).get(
            "message", ""
        )
        for ignored_type in IGNORED_EXCEPTION_TYPES:
            if ignored_type in message:
                return None

    message = event.get("message", "") or event.get("logentry", {}).get("message", "")
    for pattern in IGNORED_MESSAGE_PATTERNS:
        if pattern in message:
            return None

    sensitive_patterns = {
        "api_key",
        "api-key",
        "apikey",
        "authorization",
        "auth",
        "password",
        "passwd",
        "pwd",
        "secret",
        "token",
        "jwt",
        "dsn",
        "database_url",
        "proxy_password",
        "private_key",
        "credential",
    }

    def scrub_dict(d: dict[str, Any]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in d.items():
            key_lower = key.lower()
            if any(pattern in key_lower for pattern in sensitive_patterns):
                result[key] = "[Filtered]"
            elif isinstance(value, dict):
                result[key] = scrub_dict(value)
            elif isinstance(value, list):
                result[key] = [
                    scrub_dict(item) if isinstance(item, dict) else item
                    for item in value
                ]
            else:
                result[key] = value
        return result

    if "extra" in event:
        event["extra"] = scrub_dict(event["extra"])
    if "contexts" in event:
        event["contexts"] = scrub_dict(event["contexts"])
    if "request" in event and isinstance(event["request"], dict):
        if "headers" in event["request"]:
            event["request"]["headers"] = scrub_dict(event["request"]["headers"])
        if "data" in event["request"] and isinstance(event["request"]["data"], dict):
            event["request"]["data"] = scrub_dict(event["request"]["data"])

    trace_id = get_current_trace_id()
    span_id = get_current_span_id()

    if trace_id:
        if "tags" not in event:
            event["tags"] = {}
        event["tags"]["trace_id"] = trace_id

        if "contexts" not in event:
            event["contexts"] = {}
        event["contexts"]["trace"] = {
            "trace_id": trace_id,
            "span_id": span_id,
        }

    return event


def setup_sentry(settings: SentrySettings) -> bool:
    """Initialize Sentry SDK for error tracking with proxy support.

    Args:
        settings: Settings object with Sentry and proxy configuration.
            Must have sentry_dsn, sentry_enabled, proxy_url, etc.

    Returns:
        True if Sentry was initialized successfully, False otherwise.

    Features:
    - Proxy support via configurable proxy URL with Basic auth
    - PII scrubbing for sensitive data (api keys, passwords, tokens)
    - Graceful degradation if Sentry is unavailable
    - Integrations: asyncio, Logging
    - Trace sampling disabled by default (using OpenTelemetry instead)
    """
    from loguru import logger

    if not settings.sentry_enabled:
        logger.info("Sentry is disabled (sentry_enabled=false)")
        return False

    if not settings.sentry_dsn:
        logger.warning("Sentry DSN not configured, skipping initialization")
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.asyncio import AsyncioIntegration
        from sentry_sdk.integrations.logging import LoggingIntegration

        environment = (
            settings.sentry_environment or settings.otel_deployment_environment
        )
        http_proxy = settings.proxy_url if settings.proxy_url else None
        proxy_headers = _build_proxy_headers(settings)

        integrations = [
            AsyncioIntegration(),
            LoggingIntegration(
                level=None,
                event_level="ERROR",
            ),
        ]

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=environment,
            release=f"{settings.otel_service_name}@1.0.0",
            http_proxy=http_proxy,
            https_proxy=http_proxy,
            proxy_headers=proxy_headers,
            traces_sample_rate=settings.sentry_traces_sample_rate,
            profiles_sample_rate=0.0,
            send_default_pii=settings.sentry_send_default_pii,
            before_send=_process_event,
            integrations=integrations,
            attach_stacktrace=True,
            max_breadcrumbs=50,
            server_name=settings.otel_service_name,
        )

        dsn_masked = (
            settings.sentry_dsn[:20] + "..."
            if len(settings.sentry_dsn) > 20
            else "[hidden]"
        )
        proxy_status = f"via proxy {settings.proxy_url}" if http_proxy else "direct"

        logger.info(
            f"Sentry initialized: {settings.otel_service_name}, "
            f"env={environment}, {proxy_status}, DSN={dsn_masked}"
        )

        return True

    except ImportError as e:
        logger.warning(f"Sentry SDK not installed: {e}")
        return False
    except Exception as e:
        logger.error(f"Failed to initialize Sentry: {e}", exc_info=True)
        return False
