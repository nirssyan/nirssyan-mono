"""Marketplace repository for database operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import feeds


class MarketplaceRepository:
    """Repository for marketplace-related database operations."""

    async def get_marketplace_feeds(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        """Get marketplace feeds filtered by user's tags, excluding user's subscriptions.

        Returns only feeds that have at least one tag matching the user's tags.

        Args:
            conn: Database connection
            user_id: User ID to filter by tags and exclude from marketplace

        Returns:
            List of marketplace feed data matching user's tags

        Note:
            Refactored to use parameterized query (bindparam) instead of f-string
            to prevent SQL injection vulnerabilities (Semgrep CWE-89).
            Updated to filter feeds by user's tags using PostgreSQL array overlap operator (&&).
        """
        # List of excluded user IDs (hardcoded as in n8n workflow)
        excluded_user_ids = [
            "19e01875-c620-4292-aa4b-1c7994574e6a",
            "f2482b55-5184-4a52-89c5-a95e64e96a1d",
            str(user_id),
        ]

        # Use parameterized query with bindparam for SQL injection protection
        # PostgreSQL ANY() operator safely handles array parameters
        # Added user tags filtering using array overlap operator (&&)
        query = text("""
            WITH user_tags_array AS (
                SELECT COALESCE(array_agg(t.name), '{}') as tags
                FROM users_tags ut
                JOIN tags t ON t.id = ut.tag_id
                WHERE ut.user_id = :user_id
            ),
            excluded_feeds AS (
                SELECT DISTINCT feed_id
                FROM users_feeds
                WHERE user_id = ANY(:excluded_ids)
            )
            SELECT DISTINCT ON (feeds.id)
                   feeds.id as feed_id,
                   feeds.name,
                   feeds.tags,
                   users.id as user_id,
                   users.raw_user_meta_data ->> 'avatar_url' AS picture,
                   users.raw_user_meta_data ->> 'full_name' AS full_name
            FROM feeds
                     JOIN users_feeds ON feeds.id = users_feeds.feed_id
                     JOIN auth.users ON users_feeds.user_id = users.id
                     CROSS JOIN user_tags_array
            WHERE feeds.id NOT IN (SELECT feed_id FROM excluded_feeds)
              AND feeds.tags && user_tags_array.tags
              AND feeds.is_marketplace = true
            ORDER BY feeds.id, feeds.created_at DESC
        """)

        result = await conn.execute(
            query, {"excluded_ids": excluded_user_ids, "user_id": user_id}
        )
        rows = result.fetchall()

        return [dict(row._mapping) for row in rows]

    async def set_marketplace_feeds(
        self, conn: AsyncConnection, feed_ids: list[UUID]
    ) -> int:
        """Set is_marketplace = true for specified feeds.

        Args:
            conn: Database connection
            feed_ids: List of feed IDs to mark as marketplace feeds

        Returns:
            Number of feeds updated
        """
        query = (
            update(feeds).where(feeds.c.id.in_(feed_ids)).values(is_marketplace=True)
        )

        result = await conn.execute(query)
        return int(result.rowcount or 0)
