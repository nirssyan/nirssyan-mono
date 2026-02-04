"""Repository for telegram_users table operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import telegram_users


class TelegramUserRepository:
    """Repository for telegram_users table operations."""

    async def get_by_user_id(
        self, conn: AsyncConnection, user_id: UUID
    ) -> dict[str, Any] | None:
        """Get Telegram user record by user_id (active only).

        Args:
            conn: Database connection
            user_id: User UUID to search for

        Returns:
            Dictionary with telegram user data or None if not found/inactive
        """
        stmt = (
            select(telegram_users)
            .where(telegram_users.c.user_id == user_id)
            .where(telegram_users.c.is_active == True)  # noqa: E712
        )
        result = await conn.execute(stmt)
        row = result.fetchone()

        if row is None:
            return None

        return dict(row._mapping)

    async def unlink_by_user_id(self, conn: AsyncConnection, user_id: UUID) -> bool:
        """Unlink Telegram account by setting is_active=False.

        Args:
            conn: Database connection
            user_id: User UUID to unlink

        Returns:
            True if a record was updated, False if no active record found
        """
        stmt = (
            update(telegram_users)
            .where(telegram_users.c.user_id == user_id)
            .where(telegram_users.c.is_active == True)  # noqa: E712
            .values(is_active=False)
        )
        result = await conn.execute(stmt)
        return (result.rowcount or 0) > 0
