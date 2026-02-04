"""Trace context utilities for Sentry-OpenTelemetry correlation.

This module provides functions to link Sentry errors with OpenTelemetry traces,
enabling end-to-end error tracing across distributed services via trace_id.
"""

from typing import TYPE_CHECKING

from loguru import logger

if TYPE_CHECKING:
    from opentelemetry.trace import Span


def get_current_trace_id() -> str | None:
    """Get current OpenTelemetry trace_id as hex string.

    Returns:
        32-character hex trace_id or None if no active span.

    Example:
        >>> trace_id = get_current_trace_id()
        >>> print(trace_id)  # "0af7651916cd43dd8448eb211c80319c"
    """
    try:
        from opentelemetry import trace

        span: Span = trace.get_current_span()
        span_context = span.get_span_context()

        if span_context.is_valid:
            return format(span_context.trace_id, "032x")
        return None
    except ImportError:
        return None
    except Exception as e:
        logger.debug(f"Failed to get trace_id: {e}")
        return None


def get_current_span_id() -> str | None:
    """Get current OpenTelemetry span_id as hex string.

    Returns:
        16-character hex span_id or None if no active span.
    """
    try:
        from opentelemetry import trace

        span: Span = trace.get_current_span()
        span_context = span.get_span_context()

        if span_context.is_valid:
            return format(span_context.span_id, "016x")
        return None
    except ImportError:
        return None
    except Exception as e:
        logger.debug(f"Failed to get span_id: {e}")
        return None


def set_sentry_trace_context(request_id: str | None = None) -> None:
    """Inject trace_id and request_id into Sentry scope for error correlation.

    This function should be called at the start of each HTTP request
    (typically in middleware) to ensure all Sentry events include
    trace context for distributed tracing.

    Args:
        request_id: Optional request_id to add alongside trace_id.

    Example:
        >>> # In middleware
        >>> set_sentry_trace_context(request_id="abc-123")
        >>> # Now any Sentry error will include trace_id and request_id tags
    """
    try:
        import sentry_sdk

        if not sentry_sdk.is_initialized():
            return

        scope = sentry_sdk.get_isolation_scope()

        trace_id = get_current_trace_id()
        span_id = get_current_span_id()

        if trace_id:
            scope.set_tag("trace_id", trace_id)
            scope.set_context(
                "trace",
                {
                    "trace_id": trace_id,
                    "span_id": span_id,
                },
            )

        if request_id:
            scope.set_tag("request_id", request_id)

        if trace_id or request_id:
            logger.debug(
                f"Sentry trace context set: trace_id={trace_id}, request_id={request_id}"
            )

    except ImportError:
        pass
    except Exception as e:
        logger.debug(f"Failed to set Sentry trace context: {e}")


def add_sentry_breadcrumb_with_trace(
    message: str,
    category: str = "trace",
    level: str = "info",
    data: dict | None = None,
) -> None:
    """Add a Sentry breadcrumb with current trace context.

    Args:
        message: Breadcrumb message.
        category: Breadcrumb category (default: "trace").
        level: Breadcrumb level (debug, info, warning, error).
        data: Optional additional data.
    """
    try:
        import sentry_sdk

        if not sentry_sdk.is_initialized():
            return

        breadcrumb_data = data.copy() if data else {}

        trace_id = get_current_trace_id()
        if trace_id:
            breadcrumb_data["trace_id"] = trace_id

        sentry_sdk.add_breadcrumb(
            message=message,
            category=category,
            level=level,
            data=breadcrumb_data if breadcrumb_data else None,
        )
    except ImportError:
        pass
    except Exception as e:
        logger.debug(f"Failed to add breadcrumb: {e}")
