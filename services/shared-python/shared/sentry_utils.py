"""Sentry SDK utilities for capturing handled exceptions.

This module provides helper functions to send handled exceptions to Sentry
while keeping the original error handling logic intact.
"""

from typing import Any

from loguru import logger


def capture_exception(
    exception: BaseException,
    *,
    tags: dict[str, str] | None = None,
    extras: dict[str, Any] | None = None,
    level: str = "error",
) -> None:
    """Capture a handled exception and send to Sentry.

    This function safely captures exceptions without raising errors if Sentry
    is not configured or fails. Use this for handled exceptions that should
    be tracked in Sentry but don't crash the application.

    Args:
        exception: The exception to capture.
        tags: Optional tags for categorization (e.g., {"service": "telegram"}).
        extras: Optional extra context data.
        level: Severity level ("error", "warning", "info").

    Example:
        try:
            await nats_client.request(...)
        except NoRespondersError as e:
            capture_exception(e, tags={"service": "nats"}, extras={"subject": subject})
            raise FileNotFoundError("Service unavailable") from e
    """
    try:
        import sentry_sdk
        from sentry_sdk import Scope

        if not sentry_sdk.is_initialized():
            return

        with sentry_sdk.push_scope() as scope:
            scope: Scope
            if tags:
                for key, value in tags.items():
                    scope.set_tag(key, value)
            if extras:
                for key, value in extras.items():
                    scope.set_extra(key, value)
            scope.level = level

            sentry_sdk.capture_exception(exception)

    except ImportError:
        pass
    except Exception as e:
        logger.debug(f"Failed to capture exception in Sentry: {e}")


def capture_message(
    message: str,
    *,
    level: str = "error",
    tags: dict[str, str] | None = None,
    extras: dict[str, Any] | None = None,
) -> None:
    """Capture a message and send to Sentry.

    Use this for non-exception errors or warnings that should be tracked.

    Args:
        message: The message to capture.
        level: Severity level ("error", "warning", "info").
        tags: Optional tags for categorization.
        extras: Optional extra context data.
    """
    try:
        import sentry_sdk
        from sentry_sdk import Scope

        if not sentry_sdk.is_initialized():
            return

        with sentry_sdk.push_scope() as scope:
            scope: Scope
            if tags:
                for key, value in tags.items():
                    scope.set_tag(key, value)
            if extras:
                for key, value in extras.items():
                    scope.set_extra(key, value)
            scope.level = level

            sentry_sdk.capture_message(message, level=level)

    except ImportError:
        pass
    except Exception as e:
        logger.debug(f"Failed to capture message in Sentry: {e}")
