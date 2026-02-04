import logging
from typing import Any
from uuid import UUID

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import (
    admin_users,
    chats,
    feedbacks,
    feeds,
    posts_seen,
    user_subscriptions,
    users_feeds,
    users_tags,
)

logger = logging.getLogger(__name__)


class UserRepository:
    """Repository for user-related database operations"""

    async def delete_user(self, conn: AsyncConnection, user_id: UUID) -> dict[str, Any]:
        """
        Delete user and all associated data.

        Deletion order:
        1. Find user's feed_ids via users_feeds
        2. Delete users_feeds (user's subscriptions)
        3. Identify orphaned feeds (no remaining subscribers)
        4. Delete orphaned feeds (CASCADE: prompts → posts → sources, documents)
        5. Cancel active subscriptions (status → CANCELLED)
        6. Delete user data (chats, tags, posts_seen, feedbacks)

        Args:
            conn: Database connection
            user_id: UUID of user to delete

        Returns:
            Dictionary with deletion statistics

        Raises:
            ValueError: If user doesn't exist or has no data
        """
        try:
            # 1. Find user's feed_ids via users_feeds
            feed_ids = await self._get_user_feed_ids(conn, user_id)
            logger.info(f"Found {len(feed_ids)} feeds for user {user_id}")

            # 2. Delete users_feeds (user's subscriptions)
            deleted_users_feeds = await self._delete_user_feeds(conn, user_id)
            logger.info(f"Deleted {deleted_users_feeds} users_feeds for user {user_id}")

            # 3. Identify orphaned feeds (no remaining subscribers)
            orphaned_feeds = []
            for feed_id in feed_ids:
                subscriber_count = await self._get_feed_subscriber_count(conn, feed_id)
                if subscriber_count == 0:
                    orphaned_feeds.append(feed_id)

            logger.info(
                f"Found {len(orphaned_feeds)} orphaned feeds for user {user_id}"
            )

            # 4. Delete orphaned feeds (CASCADE: prompts → posts → sources, documents)
            for feed_id in orphaned_feeds:
                await self._delete_feed(conn, feed_id)

            logger.info(f"Deleted {len(orphaned_feeds)} orphaned feeds")

            # 5. Cancel active subscriptions (status → CANCELLED)
            cancelled_count = await self._cancel_active_subscriptions(conn, user_id)
            logger.info(f"Cancelled {cancelled_count} active subscriptions")

            # 6. Delete user data
            deleted_chats = await self._delete_user_chats(conn, user_id)
            deleted_tags = await self._delete_user_tags(conn, user_id)
            deleted_posts_seen = await self._delete_user_posts_seen(conn, user_id)
            deleted_feedbacks = await self._delete_user_feedbacks(conn, user_id)

            logger.info(
                f"Deleted user data: chats={deleted_chats}, tags={deleted_tags}, "
                f"posts_seen={deleted_posts_seen}, feedbacks={deleted_feedbacks}"
            )

            # 7. Return deletion statistics
            return {
                "user_id": str(user_id),
                "deleted_feeds": len(orphaned_feeds),
                "cancelled_subscriptions": cancelled_count,
                "deleted_chats": deleted_chats,
                "deleted_tags": deleted_tags,
                "deleted_posts_seen": deleted_posts_seen,
                "deleted_feedbacks": deleted_feedbacks,
            }

        except ValueError:
            # Re-raise for controller (404/400)
            raise
        except Exception as e:
            # Log and re-raise for controller (500)
            logger.error(f"Failed to delete user {user_id}: {e}", exc_info=True)
            raise

    async def is_user_admin(self, conn: AsyncConnection, user_id: UUID) -> bool:
        """
        Check if user has admin privileges.

        Args:
            conn: Database connection
            user_id: UUID of user to check

        Returns:
            True if user is admin, False otherwise
        """
        query = select(admin_users.c.is_admin).where(
            admin_users.c.user_id == user_id,
            admin_users.c.is_admin == True,  # noqa: E712
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return row is not None

    # Private helper methods

    async def _get_user_feed_ids(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[UUID]:
        """Get all feed_ids that user is subscribed to"""
        query = select(users_feeds.c.feed_id).where(users_feeds.c.user_id == user_id)
        result = await conn.execute(query)
        rows = result.fetchall()
        return [row[0] for row in rows]

    async def _delete_user_feeds(self, conn: AsyncConnection, user_id: UUID) -> int:
        """Delete user's feed subscriptions"""
        query = delete(users_feeds).where(users_feeds.c.user_id == user_id)
        result = await conn.execute(query)
        return int(result.rowcount or 0)

    async def _get_feed_subscriber_count(
        self, conn: AsyncConnection, feed_id: UUID
    ) -> int:
        """Get count of subscribers for a feed"""
        query = (
            select(func.count())
            .select_from(users_feeds)
            .where(users_feeds.c.feed_id == feed_id)
        )
        result = await conn.execute(query)
        count = result.scalar()
        return int(count) if count is not None else 0

    async def _delete_feed(self, conn: AsyncConnection, feed_id: UUID) -> None:
        """
        Delete feed (CASCADE deletion of prompts → posts → sources, documents).
        """
        query = delete(feeds).where(feeds.c.id == feed_id)
        await conn.execute(query)

    async def _cancel_active_subscriptions(
        self, conn: AsyncConnection, user_id: UUID
    ) -> int:
        """Cancel active subscriptions by setting status to CANCELLED"""
        query = (
            update(user_subscriptions)
            .where(
                user_subscriptions.c.user_id == user_id,
                user_subscriptions.c.status == "ACTIVE",
            )
            .values(status="CANCELLED", updated_at=func.now())
        )
        result = await conn.execute(query)
        return int(result.rowcount or 0)

    async def _delete_user_chats(self, conn: AsyncConnection, user_id: UUID) -> int:
        """Delete user's chats (CASCADE deletion of chats_messages via FK)"""
        query = delete(chats).where(chats.c.user_id == user_id)
        result = await conn.execute(query)
        return int(result.rowcount or 0)

    async def _delete_user_tags(self, conn: AsyncConnection, user_id: UUID) -> int:
        """Delete user's tag associations"""
        query = delete(users_tags).where(users_tags.c.user_id == user_id)
        result = await conn.execute(query)
        return int(result.rowcount or 0)

    async def _delete_user_posts_seen(
        self, conn: AsyncConnection, user_id: UUID
    ) -> int:
        """Delete user's posts_seen records"""
        query = delete(posts_seen).where(posts_seen.c.user_id == user_id)
        result = await conn.execute(query)
        return int(result.rowcount or 0)

    async def _delete_user_feedbacks(self, conn: AsyncConnection, user_id: UUID) -> int:
        """Delete user's feedback submissions"""
        query = delete(feedbacks).where(feedbacks.c.user_id == user_id)
        result = await conn.execute(query)
        return int(result.rowcount or 0)
