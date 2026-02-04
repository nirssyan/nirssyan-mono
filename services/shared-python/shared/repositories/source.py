"""Source repository for database operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import sources


class SourceRepository:
    """Repository for source-related database operations."""

    async def create_source(
        self,
        conn: AsyncConnection,
        post_id: UUID,
        feed_id: UUID,
        source_url: str,
    ) -> dict[str, Any] | None:
        """Create a new source record linking a post to its original URL.

        Uses ON CONFLICT DO NOTHING to handle race conditions when multiple workers
        try to create the same source simultaneously.

        Args:
            conn: Database connection
            post_id: ID of the post this source belongs to
            feed_id: ID of the feed this source belongs to
            source_url: Original URL where the post was found

        Returns:
            Dictionary containing the created source data, or None if duplicate
        """
        query = (
            insert(sources)
            .values(
                post_id=post_id,
                feed_id=feed_id,
                source_url=source_url,
            )
            .on_conflict_do_nothing(constraint="uq_sources_feed_id_source_url")
            .returning(sources)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            return None
        return dict(row._mapping)

    async def batch_create_sources(
        self,
        conn: AsyncConnection,
        sources_data: list[dict[str, Any]],
    ) -> list[UUID]:
        """Create multiple source records in a single batch operation.

        Uses ON CONFLICT DO NOTHING to handle race conditions when multiple workers
        try to create the same source simultaneously.

        Args:
            conn: Database connection
            sources_data: List of dictionaries with source data. Each dict must contain:
                - post_id: UUID
                - feed_id: UUID
                - source_url: str

        Returns:
            List of created source UUIDs (may be fewer than input if duplicates exist)
        """
        if not sources_data:
            return []

        values_list = [
            {
                "post_id": s["post_id"],
                "feed_id": s["feed_id"],
                "source_url": s["source_url"],
            }
            for s in sources_data
        ]

        query = (
            insert(sources)
            .values(values_list)
            .on_conflict_do_nothing(constraint="uq_sources_feed_id_source_url")
            .returning(sources.c.id)
        )
        result = await conn.execute(query)
        rows = result.fetchall()

        return [row[0] for row in rows]

    async def get_sources_for_posts(
        self,
        conn: AsyncConnection,
        post_ids: list[UUID],
    ) -> list[dict[str, Any]]:
        """Get all sources for multiple posts.

        Args:
            conn: Database connection
            post_ids: List of post IDs to get sources for

        Returns:
            List of source dictionaries with id, created_at, post_id, source_url
        """
        if not post_ids:
            return []
        query = select(sources).where(sources.c.post_id.in_(post_ids))
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_existing_source_urls_for_feed(
        self,
        conn: AsyncConnection,
        feed_id: UUID,
        source_urls: list[str],
    ) -> set[str]:
        """Check which source URLs already exist for a feed.

        Used for deduplication when processing raw_posts to avoid creating
        duplicate posts when NATS redelivers messages.

        Args:
            conn: Database connection
            feed_id: Feed ID to check sources for
            source_urls: List of source URLs to check

        Returns:
            Set of source URLs that already exist for this feed
        """
        if not source_urls:
            return set()

        from shared.database.tables import posts

        query = (
            select(sources.c.source_url)
            .select_from(sources.join(posts, sources.c.post_id == posts.c.id))
            .where(posts.c.feed_id == feed_id)
            .where(sources.c.source_url.in_(source_urls))
        )
        result = await conn.execute(query)
        return {row[0] for row in result.fetchall()}
