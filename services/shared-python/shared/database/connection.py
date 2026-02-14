"""Database connection utilities for all microservices."""

from typing import Any

from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

try:
    from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
except ImportError:
    SQLAlchemyInstrumentor = None  # type: ignore[assignment,misc]


class Session:
    """Async database session with automatic commit/rollback."""

    def __init__(self, db: AsyncEngine) -> None:
        self._db = db
        self.conn: Any = None

    async def __aenter__(self):  # type: ignore
        self.conn = await self._db.connect()
        return self.conn

    async def __aexit__(self, exc_type, exc_val, exc_tb):  # type: ignore
        try:
            if exc_val:
                try:
                    await self.conn.rollback()
                except Exception:
                    await self.conn.invalidate()
                    raise
            else:
                await self.conn.commit()
        finally:
            await self.conn.close()


class SessionMaker:
    """Factory for creating database sessions."""

    def __init__(self, engine: AsyncEngine):
        self._engine = engine

    def session(self) -> Session:
        return Session(self._engine)

    def __call__(self) -> Session:
        """Allow SessionMaker to be called directly to create sessions."""
        return self.session()


async def create_autocommit_connection(engine: AsyncEngine) -> Any:
    """Create a single connection for isolated writes.

    Use this for operations that need immediate commit isolation,
    such as writing individual posts in parallel.

    Args:
        engine: AsyncEngine to create connection from

    Returns:
        AsyncConnection with manual commit required
    """
    return await engine.connect()


def _instrument_engine(
    engine: AsyncEngine, otel_enabled: bool = False, trace_sql_enabled: bool = False
) -> None:
    """Instrument engine with OpenTelemetry if enabled.

    Args:
        engine: AsyncEngine to instrument
        otel_enabled: Whether OpenTelemetry is enabled
        trace_sql_enabled: Whether SQL tracing is enabled
    """
    if SQLAlchemyInstrumentor is not None and otel_enabled and trace_sql_enabled:
        sqlalchemy_instrumentor = SQLAlchemyInstrumentor()
        if not sqlalchemy_instrumentor.is_instrumented_by_opentelemetry:
            sqlalchemy_instrumentor.instrument(
                engine=engine.sync_engine,
                enable_commenter=True,
            )


def create_db_engine(
    database_url: str,
    pool_size: int = 10,
    max_overflow: int = 20,
    pool_timeout: int = 30,
    pool_recycle: int = 3600,
    echo: bool = False,
    otel_enabled: bool = False,
    trace_sql_enabled: bool = False,
) -> AsyncEngine:
    """Create AsyncEngine with configurable pool settings.

    Args:
        database_url: PostgreSQL connection string
        pool_size: Base connections in pool
        max_overflow: Additional connections when busy
        pool_timeout: Wait time for connection from pool
        pool_recycle: Recycle connections after this many seconds
        echo: Log SQL queries
        otel_enabled: Enable OpenTelemetry instrumentation
        trace_sql_enabled: Enable SQL tracing

    Returns:
        Configured AsyncEngine
    """
    if database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)

    engine = create_async_engine(
        database_url,
        echo=echo,
        pool_size=pool_size,
        max_overflow=max_overflow,
        pool_timeout=pool_timeout,
        pool_recycle=pool_recycle,
        pool_pre_ping=True,
    )

    _instrument_engine(engine, otel_enabled, trace_sql_enabled)
    return engine


def create_session_maker(engine: AsyncEngine) -> SessionMaker:
    """Create a SessionMaker for the given engine."""
    return SessionMaker(engine)


# Compatibility exports
async def get_async_connection(engine: AsyncEngine) -> Any:
    """Get a single async connection from the engine."""
    return await engine.connect()


async def get_db_session(engine: AsyncEngine) -> Session:
    """Get a database session from the engine."""
    return Session(engine)
