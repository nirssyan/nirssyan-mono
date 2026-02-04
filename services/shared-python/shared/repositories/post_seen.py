"""Post seen repository for database operations."""

from uuid import UUID

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import posts_seen


class PostSeenRepository:
    """Repository for post seen tracking operations."""

    async def mark_posts_as_seen(
        self, conn: AsyncConnection, user_id: UUID, post_ids: list[UUID]
    ) -> int:
        """Mark multiple posts as seen for a user using UPSERT.

        Uses PostgreSQL INSERT ON CONFLICT DO UPDATE to ensure idempotency.
        If a record already exists, it updates seen=true. If not, it inserts new record.
        Silently ignores posts that don't exist (foreign key constraint).

        Args:
            conn: Database connection
            user_id: ID of the user
            post_ids: List of post IDs to mark as seen

        Returns:
            Number of posts marked as seen (both new and updated records)
        """
        from sqlalchemy import select

        from shared.database.tables import posts

        # First, filter only existing posts to avoid FK constraint violation
        existing_posts_query = select(posts.c.id).where(posts.c.id.in_(post_ids))
        result = await conn.execute(existing_posts_query)
        existing_post_ids = [row.id for row in result.fetchall()]

        if not existing_post_ids:
            # No existing posts to mark
            return 0

        # Prepare values for bulk insert (only existing posts)
        values = [
            {"user_id": user_id, "post_id": post_id, "seen": True}
            for post_id in existing_post_ids
        ]

        # PostgreSQL UPSERT: INSERT ON CONFLICT DO UPDATE
        query = pg_insert(posts_seen).values(values)
        query = query.on_conflict_do_update(
            index_elements=["user_id", "post_id"],
            set_={"seen": True},
        )

        result = await conn.execute(query)
        # rowcount returns the number of affected rows (both inserted and updated)
        return int(result.rowcount or 0)
