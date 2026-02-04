"""Database engine utilities for agents service."""

from sqlalchemy.ext.asyncio import AsyncEngine

# Global database engine for LLM cost tracking
_db_engine: AsyncEngine | None = None


def get_db_engine() -> AsyncEngine | None:
    """Get global database engine for agents service."""
    return _db_engine


def set_db_engine(engine: AsyncEngine) -> None:
    """Set global database engine for agents service."""
    global _db_engine
    _db_engine = engine
