"""Repository for tags operations."""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import tags


class TagRepository:
    """Repository for managing tags in the database."""

    async def get_all_tags(self, conn: AsyncConnection) -> list[dict[str, Any]]:
        """Get all available tags ordered by name.

        Args:
            conn: Database connection

        Returns:
            List of tag dictionaries with id, name, created_at
        """
        query = select(tags).order_by(tags.c.name)
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]
