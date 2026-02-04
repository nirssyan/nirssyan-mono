"""Structured logging utilities for NATS operations."""

import time
from collections.abc import Generator
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any, Literal

from loguru import logger

PAYLOAD_PREVIEW_MAX_CHARS = 500
PAYLOAD_MAX_SIZE_BYTES = 10 * 1024  # 10KB


@dataclass
class NATSLogContext:
    """Context for structured NATS logging."""

    operation: Literal[
        "publish", "consume", "ack", "nack", "rpc_request", "rpc_response"
    ]
    subject: str
    stream: str | None = None
    event_type: str | None = None
    event_id: str | None = None
    payload_preview: str | None = None
    payload_size: int | None = None
    duration_ms: float | None = None
    batch_size: int | None = None
    success: bool | None = None
    error: str | None = None


@contextmanager
def nats_timing() -> Generator[dict[str, Any], None, None]:
    """Context manager for measuring NATS operation duration.

    Yields:
        Dictionary with 'duration_ms' key after context exits.

    Example:
        with nats_timing() as timing:
            await nc.publish(subject, data)
        print(f"Took {timing['duration_ms']}ms")
    """
    result: dict[str, Any] = {}
    start = time.perf_counter()
    try:
        yield result
    finally:
        end = time.perf_counter()
        result["duration_ms"] = round((end - start) * 1000, 2)


def should_log_payload(payload: bytes, subject: str) -> bool:
    """Determine if payload should be logged.

    Args:
        payload: Raw payload bytes
        subject: NATS subject

    Returns:
        True if payload should be logged (not too large, not media)
    """
    if len(payload) > PAYLOAD_MAX_SIZE_BYTES:
        return False
    media_keywords = ("media", "video", "download", "audio", "image", "file")
    subject_lower = subject.lower()
    return not any(keyword in subject_lower for keyword in media_keywords)


def get_payload_preview(payload: bytes, subject: str) -> str | None:
    """Get payload preview for logging.

    Args:
        payload: Raw payload bytes
        subject: NATS subject

    Returns:
        Payload preview string or None if should not log
    """
    if not should_log_payload(payload, subject):
        return None

    try:
        decoded = payload.decode("utf-8")
        if len(decoded) > PAYLOAD_PREVIEW_MAX_CHARS:
            return decoded[:PAYLOAD_PREVIEW_MAX_CHARS] + "..."
        return decoded
    except UnicodeDecodeError:
        return None


def log_nats_publish(
    subject: str,
    payload: bytes,
    stream: str | None = None,
    duration_ms: float | None = None,
    event_type: str | None = None,
) -> None:
    """Log NATS publish operation.

    Args:
        subject: NATS subject
        payload: Raw payload bytes
        stream: JetStream stream name
        duration_ms: Operation duration in milliseconds
        event_type: Event type if known
    """
    payload_preview = get_payload_preview(payload, subject)
    payload_size = len(payload)

    with logger.contextualize(
        nats_op="publish",
        nats_subject=subject,
        nats_stream=stream,
        nats_duration_ms=duration_ms,
        nats_payload_size=payload_size,
        nats_event_type=event_type,
    ):
        duration_str = f"{duration_ms}ms" if duration_ms is not None else "-"
        msg = f"NATS | publish | {duration_str} | {subject}"
        if payload_preview:
            msg += f" | {payload_preview}"
        logger.info(msg)


def log_nats_consume_start(
    subject: str,
    payload: bytes,
    event_type: str | None = None,
    event_id: str | None = None,
) -> NATSLogContext:
    """Log start of NATS consume operation.

    Args:
        subject: NATS subject
        payload: Raw payload bytes
        event_type: Event type if known
        event_id: Event ID if known

    Returns:
        NATSLogContext for use in log_nats_consume_end
    """
    payload_preview = get_payload_preview(payload, subject)
    payload_size = len(payload)

    ctx = NATSLogContext(
        operation="consume",
        subject=subject,
        event_type=event_type,
        event_id=event_id,
        payload_preview=payload_preview,
        payload_size=payload_size,
    )

    with logger.contextualize(
        nats_op="consume_start",
        nats_subject=subject,
        nats_event_type=event_type,
        nats_event_id=event_id,
        nats_payload_size=payload_size,
    ):
        msg = f"NATS | consume | start | {subject}"
        if event_type:
            msg += f" | type={event_type}"
        if payload_preview:
            msg += f" | {payload_preview}"
        logger.debug(msg)

    return ctx


def log_nats_consume_end(
    ctx: NATSLogContext,
    duration_ms: float,
    success: bool,
    error: str | None = None,
    response: Any | None = None,
) -> None:
    """Log end of NATS consume operation with input and output payloads.

    Args:
        ctx: Context from log_nats_consume_start
        duration_ms: Processing duration in milliseconds
        success: Whether processing succeeded
        error: Error message if failed
        response: Response object for request-reply handlers (Pydantic model or any)
    """
    ctx.duration_ms = duration_ms
    ctx.success = success
    ctx.error = error

    response_preview = get_request_preview(response) if response is not None else None

    with logger.contextualize(
        nats_op="consume_end",
        nats_subject=ctx.subject,
        nats_event_type=ctx.event_type,
        nats_event_id=ctx.event_id,
        nats_duration_ms=duration_ms,
        nats_success=success,
    ):
        if success:
            msg = f"NATS | consume | {duration_ms}ms | {ctx.subject}"
            if ctx.payload_preview:
                msg += f" | req: {ctx.payload_preview}"
            if response_preview:
                msg += f" | resp: {response_preview}"
            logger.info(msg)
        else:
            msg = f"NATS | consume | FAIL | {ctx.subject} | {error or 'unknown error'}"
            logger.warning(msg)


def log_nats_ack(subject: str, event_id: str | None = None) -> None:
    """Log NATS message acknowledgment.

    Args:
        subject: NATS subject
        event_id: Event ID if known
    """
    with logger.contextualize(
        nats_op="ack",
        nats_subject=subject,
        nats_event_id=event_id,
    ):
        msg = f"NATS | ack | {subject}"
        if event_id:
            msg += f" | id={event_id}"
        logger.debug(msg)


def log_nats_nack(
    subject: str, event_id: str | None = None, error: str | None = None
) -> None:
    """Log NATS message negative acknowledgment.

    Args:
        subject: NATS subject
        event_id: Event ID if known
        error: Error reason
    """
    with logger.contextualize(
        nats_op="nack",
        nats_subject=subject,
        nats_event_id=event_id,
        nats_error=error,
    ):
        msg = f"NATS | nack | {subject}"
        if event_id:
            msg += f" | id={event_id}"
        if error:
            msg += f" | {error}"
        logger.warning(msg)


def log_rpc_request(
    subject: str,
    payload: bytes,
    timeout: float | None = None,
) -> NATSLogContext:
    """Log RPC request start.

    Args:
        subject: NATS subject
        payload: Request payload bytes
        timeout: Request timeout in seconds

    Returns:
        NATSLogContext for use in log_rpc_response
    """
    payload_preview = get_payload_preview(payload, subject)
    payload_size = len(payload)

    ctx = NATSLogContext(
        operation="rpc_request",
        subject=subject,
        payload_preview=payload_preview,
        payload_size=payload_size,
    )

    with logger.contextualize(
        nats_op="rpc_request",
        nats_subject=subject,
        nats_payload_size=payload_size,
        nats_timeout=timeout,
    ):
        msg = f"NATS | rpc | start | {subject}"
        if timeout:
            msg += f" | timeout={timeout}s"
        if payload_preview:
            msg += f" | {payload_preview}"
        logger.debug(msg)

    return ctx


def log_rpc_response(
    ctx: NATSLogContext,
    response_payload: bytes | None,
    duration_ms: float,
    success: bool,
    error: str | None = None,
) -> None:
    """Log RPC response.

    Args:
        ctx: Context from log_rpc_request
        response_payload: Response payload bytes
        duration_ms: Total RPC duration in milliseconds
        success: Whether RPC succeeded
        error: Error message if failed
    """
    response_preview = None
    response_size = None
    if response_payload is not None:
        response_preview = get_payload_preview(response_payload, ctx.subject)
        response_size = len(response_payload)

    ctx.duration_ms = duration_ms
    ctx.success = success
    ctx.error = error

    with logger.contextualize(
        nats_op="rpc_response",
        nats_subject=ctx.subject,
        nats_duration_ms=duration_ms,
        nats_response_size=response_size,
        nats_success=success,
    ):
        if success:
            msg = f"NATS | rpc | {duration_ms}ms | {ctx.subject}"
            if response_preview:
                msg += f" | {response_preview}"
            logger.info(msg)
        else:
            msg = f"NATS | rpc | FAIL | {ctx.subject} | {error or 'unknown error'}"
            logger.warning(msg)


def log_rpc_timeout(subject: str, timeout: float, duration_ms: float) -> None:
    """Log RPC timeout.

    Args:
        subject: NATS subject
        timeout: Configured timeout in seconds
        duration_ms: Actual duration before timeout
    """
    with logger.contextualize(
        nats_op="rpc_timeout",
        nats_subject=subject,
        nats_timeout=timeout,
        nats_duration_ms=duration_ms,
    ):
        logger.warning(
            f"NATS | rpc | timeout | {subject} | {duration_ms}ms (limit={timeout}s)"
        )


def log_nats_batch_summary(
    subject: str,
    batch_size: int,
    successful: int,
    failed: int,
    total_duration_ms: float,
) -> None:
    """Log batch processing summary.

    Args:
        subject: NATS subject pattern
        batch_size: Total messages in batch
        successful: Successfully processed count
        failed: Failed processing count
        total_duration_ms: Total batch processing duration
    """
    with logger.contextualize(
        nats_op="batch_summary",
        nats_subject=subject,
        nats_batch_size=batch_size,
        nats_successful=successful,
        nats_failed=failed,
        nats_duration_ms=total_duration_ms,
    ):
        avg_ms = total_duration_ms / batch_size if batch_size > 0 else 0
        logger.info(
            f"NATS | batch | {total_duration_ms}ms | {subject} | "
            f"{batch_size} msgs | {successful} ok | {failed} fail | {avg_ms:.1f}ms avg"
        )


def get_request_preview(
    request: Any, max_chars: int = PAYLOAD_PREVIEW_MAX_CHARS
) -> str:
    """Get a preview of request object for logging.

    Args:
        request: Pydantic model or any object with __dict__
        max_chars: Maximum characters in preview

    Returns:
        String representation of request for logging
    """
    try:
        if hasattr(request, "model_dump"):
            data = request.model_dump()
        elif hasattr(request, "__dict__"):
            data = request.__dict__
        else:
            data = str(request)

        import json

        preview = json.dumps(data, ensure_ascii=False, default=str)
        if len(preview) > max_chars:
            return preview[:max_chars] + "..."
        return preview
    except Exception:
        return str(request)[:max_chars]


def log_rpc_handler_start(
    subject: str,
    handler_name: str,
    request: Any,
    request_id: str | None = None,
) -> NATSLogContext:
    """Log start of RPC handler processing.

    Args:
        subject: NATS subject
        handler_name: Name of the handler (e.g., "feed_filter", "view_generator")
        request: Request object (Pydantic model)
        request_id: Request ID for distributed tracing

    Returns:
        NATSLogContext for use in log_rpc_handler_end
    """
    request_preview = get_request_preview(request)

    ctx = NATSLogContext(
        operation="rpc_response",  # Server-side, so we're responding
        subject=subject,
        event_type=handler_name,
        payload_preview=request_preview,
    )

    with logger.contextualize(
        nats_op="rpc_handler_start",
        nats_subject=subject,
        nats_handler=handler_name,
        request_id=request_id,
    ):
        msg = f"NATS | handler | start | {handler_name}"
        if request_id:
            msg += f" | req_id={request_id[:8]}"
        msg += f" | {request_preview}"
        logger.debug(msg)

    return ctx


def log_rpc_handler_end(
    ctx: NATSLogContext,
    duration_ms: float,
    success: bool,
    error: str | None = None,
    response: Any | None = None,
) -> None:
    """Log end of RPC handler processing with input and output payloads.

    Args:
        ctx: Context from log_rpc_handler_start
        duration_ms: Processing duration in milliseconds
        success: Whether processing succeeded
        error: Error message if failed
        response: Response object (Pydantic model or any serializable object)
    """
    ctx.duration_ms = duration_ms
    ctx.success = success
    ctx.error = error

    response_preview = get_request_preview(response) if response is not None else None

    with logger.contextualize(
        nats_op="rpc_handler_end",
        nats_subject=ctx.subject,
        nats_handler=ctx.event_type,
        nats_duration_ms=duration_ms,
        nats_success=success,
    ):
        if success:
            msg = f"NATS | handler | {duration_ms}ms | {ctx.event_type}"
            if ctx.payload_preview:
                msg += f" | req: {ctx.payload_preview}"
            if response_preview:
                msg += f" | resp: {response_preview}"
            logger.info(msg)
        else:
            msg = (
                f"NATS | handler | FAIL | {ctx.event_type} | {error or 'unknown error'}"
            )
            logger.warning(msg)
