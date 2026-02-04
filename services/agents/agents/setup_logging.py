"""Loguru setup for makefeed-agents service."""

import logging
import sys
from types import FrameType

from loguru import logger
from opentelemetry import _logs
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from sentry_sdk.integrations.logging import BreadcrumbHandler, EventHandler

from .config import settings


def setup_otel_logging() -> LoggerProvider | None:
    """Initialize OpenTelemetry logging with OTLP export to Loki.

    Note: OTEL logs export requires a logs-compatible backend (Loki via OTLP).
    Tempo only accepts traces, so this should be disabled when using Tempo endpoint.

    Returns:
        LoggerProvider if enabled, None otherwise.
    """
    if not settings.otel_logs_enabled:
        logger.info("OTEL logs export disabled (otel_logs_enabled=false)")
        return None

    try:
        resource = Resource(
            attributes={
                SERVICE_NAME: settings.otel_service_name,
                "deployment.environment": settings.otel_deployment_environment,
                "service.version": "1.0.0",
            }
        )

        logger_provider = LoggerProvider(resource=resource)

        otlp_log_exporter = OTLPLogExporter(
            endpoint=settings.otel_exporter_otlp_endpoint,
            insecure=settings.otel_exporter_otlp_insecure,
        )

        logger_provider.add_log_record_processor(
            BatchLogRecordProcessor(otlp_log_exporter)
        )

        _logs.set_logger_provider(logger_provider)

        otel_handler = LoggingHandler(
            level=logging.INFO,
            logger_provider=logger_provider,
        )

        logger.add(
            otel_handler,
            format="{message}",
            level="INFO",
            serialize=False,
        )

        logger.info(
            f"OpenTelemetry logging initialized. "
            f"Endpoint: {settings.otel_exporter_otlp_endpoint}"
        )

        return logger_provider

    except Exception as e:
        logger.error(f"Failed to initialize OpenTelemetry logging: {e}", exc_info=True)
        return None


def setup_loguru() -> None:
    """Set up loguru logging with interception of standard logging."""
    if hasattr(setup_loguru, "_configured") and setup_loguru._configured:
        logger.debug("Logging already configured, skipping setup_loguru()")
        return

    print("=== Starting loguru configuration for makefeed-agents ===", file=sys.stderr)

    logger.remove()

    logger.level("TRACE", color="<dim>")
    logger.level("DEBUG", color="<light-cyan>")
    logger.level("INFO", color="<light-green>")
    logger.level("SUCCESS", color="<bold><light-green>")
    logger.level("WARNING", color="<bold><yellow>")
    logger.level("ERROR", color="<bold><light-red>")
    logger.level("CRITICAL", color="<bold><white><red>")

    level = "DEBUG" if settings.debug else "INFO"

    console_format = (
        "<cyan>{time:HH:mm:ss.SSS}</cyan> | "
        "<level>{level: <8}</level> | "
        "<blue>agents</blue> | "
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

            logger.opt(depth=depth, exception=record.exc_info).log(
                level, record.getMessage()
            )

    logging.root.handlers.clear()
    logging.root.setLevel(0)
    logging.root.addHandler(InterceptHandler())

    for logger_name in [
        "nats",
        "nats.aio",
        "asyncio",
        "faststream",
        "faststream.nats",
        "agents",
    ]:
        specific_logger = logging.getLogger(logger_name)
        specific_logger.handlers.clear()
        specific_logger.setLevel(0)
        specific_logger.propagate = False
        specific_logger.addHandler(InterceptHandler())

    if not settings.debug:
        for logger_name in [
            "sqlalchemy.engine",
            "sqlalchemy.pool",
            "httpx",
            "httpcore",
        ]:
            specific_logger = logging.getLogger(logger_name)
            specific_logger.setLevel(logging.WARNING)

    setup_loguru._configured = True  # type: ignore[attr-defined]

    logger.info("Loguru logging configured successfully for makefeed-agents")


def setup_sentry_logging() -> None:
    """Add Sentry handlers to loguru for error tracking.

    This function adds two Sentry handlers:
    - BreadcrumbHandler: Captures all logs as breadcrumbs for context
    - EventHandler: Sends ERROR+ logs as Sentry events

    Must be called AFTER sentry_sdk.init() and setup_loguru().
    """
    if not settings.sentry_enabled:
        logger.debug("Sentry logging disabled (sentry_enabled=false)")
        return

    level = "DEBUG" if settings.debug else "INFO"

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


class LoguruStreamHandler(logging.StreamHandler):
    """StreamHandler that redirects to loguru but appears as stdout handler.

    FastStream checks for StreamHandler with stream=sys.stdout before adding
    its own handler. By inheriting from StreamHandler with stdout, we prevent
    FastStream from adding its handler while redirecting logs to loguru.
    """

    def __init__(self) -> None:
        super().__init__(stream=sys.stdout)

    def emit(self, record: logging.LogRecord) -> None:
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = str(record.levelno)

        frame: FrameType | None = logging.currentframe()
        depth = 2
        while frame and (depth == 0 or frame.f_code.co_filename == logging.__file__):
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )


def setup_faststream_loggers() -> None:
    """Pre-configure FastStream loggers BEFORE broker starts.

    FastStream creates loggers like 'faststream.access.nats' lazily and checks
    if a StreamHandler with stream=sys.stdout exists before adding its own.
    By adding our LoguruStreamHandler first, we prevent FastStream from adding
    its handler and redirect all logs to loguru.

    This function must be called BEFORE broker.start() to intercept logs properly.
    """
    for logger_name in [
        "faststream",
        "faststream.access",
        "faststream.access.nats",
    ]:
        specific_logger = logging.getLogger(logger_name)
        specific_logger.handlers.clear()
        specific_logger.setLevel(logging.INFO)
        specific_logger.propagate = False
        specific_logger.addHandler(LoguruStreamHandler())

    logger.debug("Pre-configured FastStream loggers for loguru interception")


def intercept_faststream_loggers() -> None:
    """Intercept FastStream access loggers after broker starts.

    FastStream creates loggers like 'faststream.access.nats' lazily when broker starts.
    These loggers are created with propagate=False and their own handlers, bypassing
    our InterceptHandler. This function must be called after broker.start() to
    intercept these loggers.

    Note: If setup_faststream_loggers() was called before broker.start(),
    this function just ensures the loggers are properly configured.
    """
    for logger_name in [
        "faststream.access",
        "faststream.access.nats",
    ]:
        specific_logger = logging.getLogger(logger_name)
        has_loguru_handler = any(
            isinstance(h, LoguruStreamHandler) for h in specific_logger.handlers
        )
        if not has_loguru_handler:
            specific_logger.handlers.clear()
            specific_logger.setLevel(logging.INFO)
            specific_logger.propagate = False
            specific_logger.addHandler(LoguruStreamHandler())

    logger.debug("Intercepted FastStream access loggers")
