"""Shared loguru setup that can be imported by any service to configure logging."""

import logging
import sys
from collections.abc import Sequence
from types import FrameType

from loguru import logger
from sentry_sdk.integrations.logging import BreadcrumbHandler, EventHandler

# Common loggers to intercept across all services
DEFAULT_INTERCEPT_LOGGERS = [
    "uvicorn",
    "uvicorn.error",
    "uvicorn.access",
    "litestar",
    "nats",
    "nats.aio",
    "faststream",
    "faststream.nats",
    "httpx",
    "httpcore",
    "sqlalchemy.engine",
    "sqlalchemy.pool",
    "alembic.runtime.migration",
    "pyrogram",
    "pyrofork",
    "pyrogram.session",
    "pyrogram.connection",
    "pyrogram.dispatcher",
    "aiohttp",
    "asyncio",
]

# Loggers to suppress in production (set to WARNING level)
DEFAULT_SUPPRESS_LOGGERS = [
    "sqlalchemy.engine",
    "sqlalchemy.pool",
    "alembic.runtime.migration",
    "httpx",
    "httpcore",
]


def setup_loguru(
    service_name: str,
    debug: bool = False,
    intercept_loggers: Sequence[str] | None = None,
    suppress_loggers: Sequence[str] | None = None,
) -> None:
    """
    Set up loguru logging with interception of standard logging.

    Args:
        service_name: Name of the service (used in log format)
        debug: Enable debug level logging
        intercept_loggers: Additional loggers to intercept (added to defaults)
        suppress_loggers: Additional loggers to suppress in production
    """
    if hasattr(setup_loguru, "_configured") and setup_loguru._configured:
        logger.debug("Logging already configured, skipping setup_loguru()")
        return

    print(f"=== Starting loguru configuration for {service_name} ===", file=sys.stderr)

    logger.remove()

    logger.level("TRACE", color="<dim>")
    logger.level("DEBUG", color="<light-cyan>")
    logger.level("INFO", color="<light-green>")
    logger.level("SUCCESS", color="<bold><light-green>")
    logger.level("WARNING", color="<bold><yellow>")
    logger.level("ERROR", color="<bold><light-red>")
    logger.level("CRITICAL", color="<bold><white><red>")

    level = "DEBUG" if debug else "INFO"

    console_format = (
        "<cyan>{time:YYYY-MM-DD HH:mm:ss.SSS}</cyan> | "
        "<level>{level: <8}</level> | "
        f"<blue>{service_name}</blue> | "
        "<level>{message}</level>"
    )

    logger.add(
        sys.stderr,
        level=level,
        format=console_format,
        colorize=True,
        enqueue=True,
    )

    class InterceptHandler(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            try:
                level = logger.level(record.levelname).name
            except ValueError:
                level = str(record.levelno)

            frame: FrameType | None = logging.currentframe()
            depth = 2
            while frame and (
                depth == 0 or frame.f_code.co_filename == logging.__file__
            ):
                frame = frame.f_back
                depth += 1

            exc_info = record.exc_info
            if exc_info and exc_info[0]:
                exc_class_name = exc_info[0].__name__
                if exc_class_name in ("HTTPException", "ValidationException"):
                    exc_info = None

            logger.opt(depth=depth, exception=exc_info).log(level, record.getMessage())

    logging.root.handlers.clear()
    logging.root.setLevel(0)
    logging.root.addHandler(InterceptHandler())

    # Combine default and custom loggers to intercept
    loggers_to_intercept = list(DEFAULT_INTERCEPT_LOGGERS)
    if intercept_loggers:
        loggers_to_intercept.extend(intercept_loggers)

    for logger_name in loggers_to_intercept:
        specific_logger = logging.getLogger(logger_name)
        specific_logger.handlers.clear()
        specific_logger.setLevel(0)
        specific_logger.propagate = False
        specific_logger.addHandler(InterceptHandler())

    # Suppress verbose loggers in production
    if not debug:
        loggers_to_suppress = list(DEFAULT_SUPPRESS_LOGGERS)
        if suppress_loggers:
            loggers_to_suppress.extend(suppress_loggers)

        for logger_name in loggers_to_suppress:
            specific_logger = logging.getLogger(logger_name)
            specific_logger.setLevel(logging.WARNING)

    setup_loguru._configured = True  # type: ignore[attr-defined]

    logger.info(f"Loguru logging configured successfully for {service_name}")


def setup_sentry_logging(sentry_enabled: bool = True, debug: bool = False) -> None:
    """Add Sentry handlers to loguru for error tracking.

    This function adds two Sentry handlers:
    - BreadcrumbHandler: Captures all logs as breadcrumbs for context
    - EventHandler: Sends ERROR+ logs as Sentry events

    Must be called AFTER sentry_sdk.init() and setup_loguru().

    Args:
        sentry_enabled: Whether Sentry is enabled (skip if False)
        debug: Whether debug mode is enabled (affects log level for breadcrumbs)
    """
    if not sentry_enabled:
        logger.debug("Sentry logging disabled (sentry_enabled=false)")
        return

    level = "DEBUG" if debug else "INFO"

    logger.add(
        BreadcrumbHandler(level=logging.DEBUG),
        level=level,
        format="{message}",
    )

    logger.add(
        EventHandler(level=logging.ERROR),
        level="ERROR",
        format="{message}",
    )

    logger.info("Sentry logging handlers added (breadcrumbs + ERROR events)")
