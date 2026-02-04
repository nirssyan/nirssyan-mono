"""Database utilities: connection pool and table definitions."""

from shared.database.connection import (
    Session,
    SessionMaker,
    create_autocommit_connection,
    create_db_engine,
    create_session_maker,
    get_async_connection,
    get_db_session,
)
from shared.database.tables import (
    chats,
    chats_messages,
    feeds,
    messages,
    metadata,
    posts,
    prompts,
    raw_feeds,
    raw_posts,
    social_accounts,
    subscriptions,
    telegram_users,
)

__all__ = [
    # Connection utilities
    "Session",
    "SessionMaker",
    "create_autocommit_connection",
    "create_db_engine",
    "create_session_maker",
    "get_async_connection",
    "get_db_session",
    # Metadata
    "metadata",
    # Tables
    "chats",
    "chats_messages",
    "feeds",
    "messages",
    "posts",
    "prompts",
    "raw_feeds",
    "raw_posts",
    "social_accounts",
    "subscriptions",
    "telegram_users",
]
