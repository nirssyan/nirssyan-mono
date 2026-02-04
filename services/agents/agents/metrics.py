"""OpenTelemetry metrics for makefeed-processor service."""

from opentelemetry import metrics

from .config import settings


def get_meter() -> metrics.Meter:
    """Get the global meter from OpenTelemetry MeterProvider.

    Returns:
        Meter instance for creating metrics
    """
    return metrics.get_meter(__name__)


# Initialize meter
_meter = get_meter()

# ============================================================================
# COUNTER METRICS
# ============================================================================

# Posts created by feed processing type
posts_created_counter = _meter.create_counter(
    name="posts_created_total",
    description="Total number of posts created, labeled by feed type",
    unit="1",
)

# LLM requests
llm_requests_counter = _meter.create_counter(
    name="llm_requests_total",
    description="Total number of LLM API requests, labeled by agent",
    unit="1",
)

# LLM tokens (input/output)
llm_tokens_counter = _meter.create_counter(
    name="llm_tokens_total",
    description="Total number of LLM tokens used, labeled by agent, model, and token_type",
    unit="1",
)

# LLM cost in USD (stored as microdollars for precision)
llm_cost_counter = _meter.create_counter(
    name="llm_cost_usd_total",
    description="Total LLM cost in USD, labeled by agent and model",
    unit="1",
)

# Feed processing background metrics
feed_processing_counter = _meter.create_counter(
    name="feed_processing_total",
    description="Total number of processing attempts, labeled by status and type",
    unit="1",
)

feed_processing_errors_counter = _meter.create_counter(
    name="feed_processing_errors_total",
    description="Total number of processing errors, labeled by type",
    unit="1",
)

# NATS consumer metrics
nats_messages_consumed_counter = _meter.create_counter(
    name="nats_messages_consumed_total",
    description="Total number of NATS messages consumed, labeled by subject",
    unit="1",
)

nats_messages_acked_counter = _meter.create_counter(
    name="nats_messages_acked_total",
    description="Total number of NATS messages acknowledged",
    unit="1",
)

nats_messages_nacked_counter = _meter.create_counter(
    name="nats_messages_nacked_total",
    description="Total number of NATS messages negatively acknowledged",
    unit="1",
)

# ============================================================================
# HISTOGRAM METRICS
# ============================================================================

# Feed processing duration histogram
feed_processing_duration_histogram = _meter.create_histogram(
    name="feed_processing_duration_seconds",
    description="Duration of feed processing operations, labeled by prompt type and phase",
    unit="s",
)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================


def increment_posts_created(feed_type: str, count: int = 1) -> None:
    """Increment posts created counter.

    Args:
        feed_type: Type of feed (SINGLE_POST, DIGEST)
        count: Number to increment by (default: 1)
    """
    if not settings.otel_enabled:
        return
    posts_created_counter.add(count, {"feed_type": feed_type})


def increment_llm_requests(agent: str, count: int = 1) -> None:
    """Increment LLM requests counter.

    Args:
        agent: Name of AI agent (filter, summary, comment, title, etc.)
        count: Number to increment by (default: 1)
    """
    if not settings.otel_enabled:
        return
    llm_requests_counter.add(count, {"agent": agent})


def increment_llm_tokens(
    agent: str, model: str, prompt_tokens: int, completion_tokens: int
) -> None:
    """Increment LLM tokens counter.

    Args:
        agent: Name of AI agent class
        model: Model name used (e.g., meta-llama/llama-3.1-8b-instruct)
        prompt_tokens: Number of input tokens
        completion_tokens: Number of output tokens
    """
    if not settings.otel_enabled:
        return

    if prompt_tokens > 0:
        llm_tokens_counter.add(
            prompt_tokens, {"agent": agent, "model": model, "token_type": "input"}
        )

    if completion_tokens > 0:
        llm_tokens_counter.add(
            completion_tokens, {"agent": agent, "model": model, "token_type": "output"}
        )


def increment_llm_cost(agent: str, model: str, cost_usd: float) -> None:
    """Increment LLM cost counter.

    Cost is stored in microdollars (USD * 1_000_000) for precision with counters.

    Args:
        agent: Name of AI agent class
        model: Model name used
        cost_usd: Cost in USD
    """
    if not settings.otel_enabled:
        return

    if cost_usd > 0:
        # Convert to microdollars for counter precision (counters are integers)
        cost_microdollars = int(cost_usd * 1_000_000)
        if cost_microdollars > 0:
            llm_cost_counter.add(cost_microdollars, {"agent": agent, "model": model})


def increment_processing(status: str, prompt_type: str, count: int = 1) -> None:
    """Increment processing attempts counter.

    Args:
        status: Status of processing attempt (success, error)
        prompt_type: Type of prompt (SINGLE_POST, DIGEST)
        count: Number to increment by (default: 1)
    """
    if not settings.otel_enabled:
        return
    feed_processing_counter.add(count, {"status": status, "prompt_type": prompt_type})


def increment_processing_errors(prompt_type: str, count: int = 1) -> None:
    """Increment processing errors counter.

    Args:
        prompt_type: Type of prompt that failed
        count: Number to increment by (default: 1)
    """
    if not settings.otel_enabled:
        return
    feed_processing_errors_counter.add(count, {"prompt_type": prompt_type})


def increment_nats_consumed(subject: str, count: int = 1) -> None:
    """Increment NATS messages consumed counter.

    Args:
        subject: NATS subject
        count: Number to increment by (default: 1)
    """
    if not settings.otel_enabled:
        return
    nats_messages_consumed_counter.add(count, {"subject": subject})


def increment_nats_acked(count: int = 1) -> None:
    """Increment NATS messages acknowledged counter."""
    if not settings.otel_enabled:
        return
    nats_messages_acked_counter.add(count)


def increment_nats_nacked(count: int = 1) -> None:
    """Increment NATS messages negatively acknowledged counter."""
    if not settings.otel_enabled:
        return
    nats_messages_nacked_counter.add(count)


def record_processing_duration(
    prompt_type: str, phase: str, duration_seconds: float
) -> None:
    """Record feed processing duration.

    Args:
        prompt_type: Type of prompt (SINGLE_POST, DIGEST)
        phase: Processing phase (total, llm, db_fetch, db_write)
        duration_seconds: Duration in seconds
    """
    if not settings.otel_enabled:
        return
    feed_processing_duration_histogram.record(
        duration_seconds, {"prompt_type": prompt_type, "phase": phase}
    )
