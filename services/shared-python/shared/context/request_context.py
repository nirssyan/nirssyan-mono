"""Request context for cross-service tracing via NATS."""

from contextvars import ContextVar

request_id_ctx_var: ContextVar[str | None] = ContextVar("request_id", default=None)


def get_request_id() -> str | None:
    """Get current request ID from async context.

    Returns:
        Request ID string or None if not in request context
    """
    return request_id_ctx_var.get()


def set_request_id(request_id: str | None) -> None:
    """Set request ID in async context.

    Args:
        request_id: Request ID string or None to clear
    """
    request_id_ctx_var.set(request_id)
