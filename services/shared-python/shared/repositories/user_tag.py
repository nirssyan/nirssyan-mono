"""Repository for user tags operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import delete, insert, select, text
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import tags, users_tags


class UserTagRepository:
    """Repository for managing user tags in the database."""

    async def get_user_tags(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        """Get all tags for a specific user with tag details.

        Args:
            conn: Database connection
            user_id: User UUID

        Returns:
            List of user tag dictionaries with nested tag information
        """
        query = text("""
            SELECT
                users_tags.id,
                users_tags.user_id,
                users_tags.created_at,
                json_build_object(
                    'id', tags.id,
                    'name', tags.name
                ) as tag
            FROM users_tags
            JOIN tags ON tags.id = users_tags.tag_id
            WHERE users_tags.user_id = :user_id
            ORDER BY tags.name
        """)

        result = await conn.execute(query, {"user_id": user_id})
        return [dict(row._mapping) for row in result.fetchall()]

    async def set_user_tags(
        self, conn: AsyncConnection, user_id: UUID, tag_ids: list[UUID]
    ) -> int:
        """Replace all user tags with a new set of tags.

        This method deletes all existing user tags and inserts new ones.

        Args:
            conn: Database connection
            user_id: User UUID
            tag_ids: List of tag IDs to set (can be empty to clear all tags)

        Returns:
            Number of tags set
        """
        # Delete all existing user tags
        delete_query = delete(users_tags).where(users_tags.c.user_id == user_id)
        await conn.execute(delete_query)

        # If no tag_ids provided, just return 0 (all tags cleared)
        if not tag_ids:
            return 0

        # Insert new user tags
        values = [{"user_id": user_id, "tag_id": tag_id} for tag_id in tag_ids]
        insert_query = insert(users_tags).values(values)
        await conn.execute(insert_query)

        return len(tag_ids)

    async def validate_tag_ids(
        self, conn: AsyncConnection, tag_ids: list[UUID]
    ) -> list[UUID]:
        """Validate that all provided tag IDs exist in the database.

        Args:
            conn: Database connection
            tag_ids: List of tag IDs to validate

        Returns:
            List of valid tag IDs that exist in database

        Raises:
            ValueError: If any tag IDs are invalid
        """
        if not tag_ids:
            return []

        query = select(tags.c.id).where(tags.c.id.in_(tag_ids))
        result = await conn.execute(query)
        valid_ids = [row[0] for row in result.fetchall()]

        invalid_ids = set(tag_ids) - set(valid_ids)
        if invalid_ids:
            raise ValueError(
                f"Invalid tag IDs: {', '.join(str(id) for id in invalid_ids)}"
            )

        return valid_ids
