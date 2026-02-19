"""OpenTelemetry metrics for makefeed-processor service.

Instruments are created lazily on first use so that the real MeterProvider
(with PrometheusMetricReader) is already installed by setup_opentelemetry().
Creating instruments at import time would bind them to the no-op proxy provider.
"""

from functools import lru_cache

from opentelemetry import metrics

from .config import settings


def _get_meter() -> metrics.Meter:
    return metrics.get_meter(__name__)


@lru_cache(maxsize=1)
def _posts_created_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="posts_created_total",
        description="Total number of posts created, labeled by feed type",
        unit="1",
    )


@lru_cache(maxsize=1)
def _llm_requests_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="llm_requests_total",
        description="Total number of LLM API requests, labeled by agent",
        unit="1",
    )


@lru_cache(maxsize=1)
def _llm_tokens_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="llm_tokens_total",
        description="Total number of LLM tokens used, labeled by agent, model, and token_type",
        unit="1",
    )


@lru_cache(maxsize=1)
def _llm_cost_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="llm_cost_usd_total",
        description="Total LLM cost in USD, labeled by agent and model",
        unit="1",
    )


@lru_cache(maxsize=1)
def _feed_processing_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="feed_processing_total",
        description="Total number of processing attempts, labeled by status and type",
        unit="1",
    )


@lru_cache(maxsize=1)
def _feed_processing_errors_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="feed_processing_errors_total",
        description="Total number of processing errors, labeled by type",
        unit="1",
    )


@lru_cache(maxsize=1)
def _nats_messages_consumed_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="nats_messages_consumed_total",
        description="Total number of NATS messages consumed, labeled by subject",
        unit="1",
    )


@lru_cache(maxsize=1)
def _nats_messages_acked_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="nats_messages_acked_total",
        description="Total number of NATS messages acknowledged",
        unit="1",
    )


@lru_cache(maxsize=1)
def _nats_messages_nacked_counter() -> metrics.Counter:
    return _get_meter().create_counter(
        name="nats_messages_nacked_total",
        description="Total number of NATS messages negatively acknowledged",
        unit="1",
    )


@lru_cache(maxsize=1)
def _feed_processing_duration_histogram() -> metrics.Histogram:
    return _get_meter().create_histogram(
        name="feed_processing_duration_seconds",
        description="Duration of feed processing operations, labeled by prompt type and phase",
        unit="s",
    )


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================


def increment_posts_created(feed_type: str, count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _posts_created_counter().add(count, {"feed_type": feed_type})


def increment_llm_requests(agent: str, count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _llm_requests_counter().add(count, {"agent": agent})


def increment_llm_tokens(
    agent: str, model: str, prompt_tokens: int, completion_tokens: int
) -> None:
    if not settings.otel_enabled:
        return

    if prompt_tokens > 0:
        _llm_tokens_counter().add(
            prompt_tokens, {"agent": agent, "model": model, "token_type": "input"}
        )

    if completion_tokens > 0:
        _llm_tokens_counter().add(
            completion_tokens, {"agent": agent, "model": model, "token_type": "output"}
        )


def increment_llm_cost(agent: str, model: str, cost_usd: float) -> None:
    if not settings.otel_enabled:
        return

    if cost_usd > 0:
        cost_microdollars = int(cost_usd * 1_000_000)
        if cost_microdollars > 0:
            _llm_cost_counter().add(cost_microdollars, {"agent": agent, "model": model})


def increment_processing(status: str, prompt_type: str, count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _feed_processing_counter().add(
        count, {"status": status, "prompt_type": prompt_type}
    )


def increment_processing_errors(prompt_type: str, count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _feed_processing_errors_counter().add(count, {"prompt_type": prompt_type})


def increment_nats_consumed(subject: str, count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _nats_messages_consumed_counter().add(count, {"subject": subject})


def increment_nats_acked(count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _nats_messages_acked_counter().add(count)


def increment_nats_nacked(count: int = 1) -> None:
    if not settings.otel_enabled:
        return
    _nats_messages_nacked_counter().add(count)


def record_processing_duration(
    prompt_type: str, phase: str, duration_seconds: float
) -> None:
    if not settings.otel_enabled:
        return
    _feed_processing_duration_histogram().record(
        duration_seconds, {"prompt_type": prompt_type, "phase": phase}
    )
