"""Main entrypoint for makefeed-agents service.

This service hosts all AI agents and exposes them via NATS RPC.
Other services call agents through NATS request-reply pattern.

Uses FastStream for NATS messaging.
"""

import asyncio
import logging
import signal
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from faststream.nats import NatsBroker
from faststream.nats.opentelemetry import NatsTelemetryMiddleware
from loguru import logger

from shared.database.connection import create_db_engine
from shared.setup_sentry import setup_sentry
from shared.utils.llm_pricing import load_pricing_from_db

from .config import settings
from .handlers import setup_agent_handlers
from .setup_logging import (
    intercept_faststream_loggers,
    setup_faststream_loggers,
    setup_loguru,
    setup_otel_logging,
    setup_sentry_logging,
)
from .setup_opentelemetry import setup_opentelemetry
from .utils.db import get_db_engine, set_db_engine


def create_agents_broker() -> NatsBroker:
    middlewares = (NatsTelemetryMiddleware(),) if settings.otel_enabled else ()
    faststream_logger = logging.getLogger("faststream")
    return NatsBroker(settings.nats_url, logger=faststream_logger, middlewares=middlewares)


class AgentsApp:
    """Main application class for makefeed-agents."""

    def __init__(self) -> None:
        self._running = False
        self._broker: NatsBroker | None = None

    @asynccontextmanager
    async def lifespan(self) -> AsyncIterator[None]:
        """Application lifespan context manager."""
        await self._startup()
        try:
            yield
        finally:
            await self._shutdown()

    async def _startup(self) -> None:
        """Initialize application components."""
        logger.info("Starting makefeed-agents service...")

        # Create database engine if database_url is configured
        if settings.database_url:
            engine = create_db_engine(
                database_url=settings.database_url,
                pool_size=settings.database_pool_size,
                max_overflow=settings.database_max_overflow,
                pool_recycle=settings.database_pool_recycle,
                echo=settings.debug,
                otel_enabled=settings.otel_enabled,
                trace_sql_enabled=settings.otel_trace_sql_enabled,
            )
            set_db_engine(engine)
            logger.info("Database engine created for LLM cost tracking")

            # Load LLM pricing from database into cache
            async with engine.connect() as conn:
                await load_pricing_from_db(conn)
            logger.info("LLM pricing cache loaded from database")
        else:
            logger.warning(
                "database_url not configured - LLM cost tracking to database will be disabled"
            )

        # Create and configure broker
        self._broker = create_agents_broker()

        # Setup RPC handlers (registers subscribers)
        setup_agent_handlers(self._broker)

        # Pre-configure FastStream loggers BEFORE broker starts
        # This adds placeholder handlers that prevent FastStream from adding its own
        setup_faststream_loggers()

        # Start broker (connects to NATS)
        await self._broker.start()

        # Ensure FastStream access loggers are intercepted after broker creates them
        intercept_faststream_loggers()

        self._running = True

        logger.info(f"makefeed-agents started (NATS: {settings.nats_url})")

    async def _shutdown(self) -> None:
        """Cleanup application components."""
        logger.info("Shutting down makefeed-agents service...")
        self._running = False

        # Stop broker (closes NATS connection)
        if self._broker:
            await self._broker.close()

        # Dispose database engine
        engine = get_db_engine()
        if engine:
            await engine.dispose()
            logger.info("Database engine disposed")

        # Cancel any remaining tasks
        pending_tasks = [
            task for task in asyncio.all_tasks() if task is not asyncio.current_task()
        ]
        if pending_tasks:
            logger.info(f"Cancelling {len(pending_tasks)} pending tasks...")
            for task in pending_tasks:
                task.cancel()
            await asyncio.gather(*pending_tasks, return_exceptions=True)
            logger.info("All pending tasks cancelled")

        logger.info("makefeed-agents shutdown complete")

    async def run(self) -> None:
        """Run the agents service."""
        async with self.lifespan():
            # Keep running until shutdown signal
            while self._running:
                await asyncio.sleep(1.0)


def setup_signal_handlers(app: AgentsApp, loop: asyncio.AbstractEventLoop) -> None:
    """Setup signal handlers for graceful shutdown."""

    def handle_signal(sig: signal.Signals) -> None:
        logger.info(f"Received signal {sig.name}, initiating shutdown...")
        app._running = False

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, lambda s=sig: handle_signal(s))


def main() -> None:
    """Main entrypoint."""
    # Initialize OpenTelemetry first
    setup_opentelemetry()

    # Initialize Sentry for error tracking
    setup_sentry(settings)

    setup_loguru()
    setup_sentry_logging()
    setup_otel_logging()

    logger.info(f"Starting makefeed-agents (NATS: {settings.nats_url})")

    # Create application
    app = AgentsApp()

    # Get event loop and setup signal handlers
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    setup_signal_handlers(app, loop)

    try:
        loop.run_until_complete(app.run())
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        loop.close()
        logger.info("Event loop closed")


if __name__ == "__main__":
    main()
