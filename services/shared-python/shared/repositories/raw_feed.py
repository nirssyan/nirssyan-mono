from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from loguru import logger
from sqlalchemy import func, insert, select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import prompts_raw_feeds, raw_feeds
from shared.enums import PollingTier, RawType


def normalize_telegram_username(username: str | None) -> str | None:
    """Normalize Telegram username for consistent storage.

    Removes:
    - @ prefix
    - https://t.me/ URL prefix
    - Trailing slashes and whitespace

    Also converts to lowercase for case-insensitive matching
    (Telegram usernames are case-insensitive).
    """
    if not username:
        return None

    username = username.strip()

    for prefix in ["https://t.me/", "http://t.me/", "t.me/"]:
        if username.lower().startswith(prefix):
            username = username[len(prefix) :]
            break

    if username.startswith("@"):
        username = username[1:]

    return username.strip("/").lower()


class RawFeedRepository:
    """Repository for raw_feeds table operations."""

    async def get_or_create_telegram_channel(
        self,
        conn: AsyncConnection,
        telegram_username: str,
        telegram_chat_id: int,
        name: str,
    ) -> dict[str, Any]:
        """Get or create a raw_feed for a Telegram channel.

        Args:
            conn: Database connection
            telegram_username: Channel @username (without @)
            telegram_chat_id: Telegram numeric chat ID
            name: Channel display name

        Returns:
            Dictionary containing raw_feed data
        """
        telegram_username = normalize_telegram_username(telegram_username) or ""

        # Check if exists by telegram_username
        query = select(raw_feeds).where(
            raw_feeds.c.telegram_username == telegram_username
        )
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            raw_feed_data = dict(row._mapping)
            # Update telegram_chat_id if missing (for legacy raw_feeds created before this field was added)
            if raw_feed_data.get("telegram_chat_id") is None and telegram_chat_id:
                update_query = (
                    update(raw_feeds)
                    .where(raw_feeds.c.id == raw_feed_data["id"])
                    .values(telegram_chat_id=telegram_chat_id)
                    .returning(raw_feeds)
                )
                result = await conn.execute(update_query)
                updated_row = result.fetchone()
                if updated_row:
                    raw_feed_data = dict(updated_row._mapping)
                    logger.info(
                        f"Updated telegram_chat_id for @{telegram_username}: {telegram_chat_id}"
                    )
            else:
                logger.info(f"Found existing raw_feed for @{telegram_username}")
            return raw_feed_data

        # Create new raw_feed
        insert_query = (
            insert(raw_feeds)
            .values(
                name=name,
                raw_type=RawType.TELEGRAM,
                telegram_chat_id=telegram_chat_id,
                telegram_username=telegram_username,
                feed_url=f"https://t.me/{telegram_username}",
                site_url=f"https://t.me/{telegram_username}",
                polling_tier=PollingTier.WARM,
            )
            .returning(raw_feeds)
        )

        result = await conn.execute(insert_query)
        row = result.fetchone()

        if row is None:
            raise ValueError(f"Failed to create raw_feed for @{telegram_username}")

        logger.info(f"Created new raw_feed for @{telegram_username}")
        return dict(row._mapping)

    async def get_or_create_telegram_channel_by_username(
        self,
        conn: AsyncConnection,
        telegram_username: str,
        name: str | None = None,
    ) -> dict[str, Any]:
        """Get or create a raw_feed for a Telegram channel using only username.

        Creates a Telegram raw_feed without chat_id. The chat_id will be populated
        later by the background poller when it first fetches the channel.

        Args:
            conn: Database connection
            telegram_username: Channel @username, t.me/channel, or URL
            name: Optional display name (defaults to username if not provided)

        Returns:
            Dictionary containing raw_feed data
        """
        normalized_username = normalize_telegram_username(telegram_username) or ""

        if not normalized_username:
            raise ValueError("Invalid Telegram username")

        # Check if exists by telegram_username
        query = select(raw_feeds).where(
            raw_feeds.c.telegram_username == normalized_username
        )
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            logger.info(f"Found existing raw_feed for @{normalized_username}")
            return dict(row._mapping)

        # Create new raw_feed without chat_id
        display_name = name or f"@{normalized_username}"
        insert_query = (
            insert(raw_feeds)
            .values(
                name=display_name,
                raw_type=RawType.TELEGRAM,
                telegram_username=normalized_username,
                feed_url=f"https://t.me/{normalized_username}",
                site_url=f"https://t.me/{normalized_username}",
                polling_tier=PollingTier.WARM,
            )
            .returning(raw_feeds)
        )

        result = await conn.execute(insert_query)
        row = result.fetchone()

        if row is None:
            raise ValueError(f"Failed to create raw_feed for @{normalized_username}")

        logger.info(
            f"Created new raw_feed for @{normalized_username} (chat_id pending)"
        )
        return dict(row._mapping)

    async def get_or_create_rss_feed(
        self,
        conn: AsyncConnection,
        feed_url: str,
        name: str,
        site_url: str | None = None,
    ) -> dict[str, Any]:
        """Get or create a raw_feed for an RSS/Web source.

        Args:
            conn: Database connection
            feed_url: RSS feed URL or website URL
            name: Display name for the feed
            site_url: Optional website URL (if different from feed_url)

        Returns:
            Dictionary containing raw_feed data
        """
        # Check if exists by feed_url
        query = select(raw_feeds).where(raw_feeds.c.feed_url == feed_url)
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            logger.info(f"Found existing raw_feed for {feed_url}")
            return dict(row._mapping)

        # Create new raw_feed
        insert_query = (
            insert(raw_feeds)
            .values(
                name=name,
                raw_type=RawType.RSS,
                feed_url=feed_url,
                site_url=site_url or feed_url,
                polling_tier=PollingTier.WARM,
            )
            .returning(raw_feeds)
        )

        result = await conn.execute(insert_query)
        row = result.fetchone()

        if row is None:
            raise ValueError(f"Failed to create raw_feed for {feed_url}")

        logger.info(f"Created new raw_feed for {feed_url}")
        return dict(row._mapping)

    async def get_or_create_youtube_feed(
        self,
        conn: AsyncConnection,
        feed_url: str,
        name: str,
        site_url: str,
    ) -> dict[str, Any]:
        """Get or create a raw_feed for a YouTube channel."""
        query = select(raw_feeds).where(raw_feeds.c.feed_url == feed_url)
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            return dict(row._mapping)

        insert_query = (
            insert(raw_feeds)
            .values(
                name=name,
                raw_type=RawType.YOUTUBE,
                feed_url=feed_url,
                site_url=site_url,
                polling_tier=PollingTier.WARM,
            )
            .returning(raw_feeds)
        )

        result = await conn.execute(insert_query)
        row = result.fetchone()
        if row is None:
            raise ValueError(f"Failed to create raw_feed for {feed_url}")

        logger.info(f"Created new YouTube raw_feed: {name}")
        return dict(row._mapping)

    async def get_or_create_reddit_feed(
        self,
        conn: AsyncConnection,
        feed_url: str,
        name: str,
        site_url: str,
    ) -> dict[str, Any]:
        """Get or create a raw_feed for a Reddit source."""
        query = select(raw_feeds).where(raw_feeds.c.feed_url == feed_url)
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            return dict(row._mapping)

        insert_query = (
            insert(raw_feeds)
            .values(
                name=name,
                raw_type=RawType.REDDIT,
                feed_url=feed_url,
                site_url=site_url,
                polling_tier=PollingTier.WARM,
            )
            .returning(raw_feeds)
        )

        result = await conn.execute(insert_query)
        row = result.fetchone()
        if row is None:
            raise ValueError(f"Failed to create raw_feed for {feed_url}")

        logger.info(f"Created new Reddit raw_feed: {name}")
        return dict(row._mapping)

    async def get_telegram_channels_for_update(
        self, conn: AsyncConnection
    ) -> list[dict[str, Any]]:
        """Get all Telegram channels that need to be updated.

        Args:
            conn: Database connection

        Returns:
            List of dictionaries containing raw_feed data
        """
        query = select(raw_feeds).where(raw_feeds.c.raw_type == RawType.TELEGRAM)
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_rss_feeds_for_update(
        self, conn: AsyncConnection
    ) -> list[dict[str, Any]]:
        """Get all RSS/Web feeds that need to be updated.

        Args:
            conn: Database connection

        Returns:
            List of dictionaries containing raw_feed data
        """
        query = select(raw_feeds).where(
            raw_feeds.c.raw_type.in_([RawType.RSS, RawType.YOUTUBE, RawType.REDDIT])
        )
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_rss_feeds_due_for_poll(
        self,
        conn: AsyncConnection,
        tier_intervals: dict[str, int],
    ) -> list[dict[str, Any]]:
        """Get RSS/YouTube/Reddit feeds that are due for polling based on their tier.

        Args:
            conn: Database connection
            tier_intervals: Mapping of PollingTier value to interval in seconds
        """
        now = datetime.now(timezone.utc)
        rss_types = [RawType.RSS, RawType.YOUTUBE, RawType.REDDIT]
        all_feeds: list[dict[str, Any]] = []

        for tier_value, interval_seconds in tier_intervals.items():
            cutoff = now - timedelta(seconds=interval_seconds)
            query = (
                select(raw_feeds)
                .where(
                    raw_feeds.c.raw_type.in_(rss_types),
                    raw_feeds.c.polling_tier == tier_value,
                )
                .where(
                    (raw_feeds.c.last_polled_at.is_(None))
                    | (raw_feeds.c.last_polled_at < cutoff)
                )
            )
            result = await conn.execute(query)
            all_feeds.extend(dict(row._mapping) for row in result.fetchall())

        return all_feeds

    async def update_rss_poll_result(
        self,
        conn: AsyncConnection,
        raw_feed_id: UUID,
        new_posts_count: int,
        error: bool = False,
    ) -> None:
        """Update feed after poll: set last_polled_at and adjust tier/error_count."""
        values: dict[str, Any] = {"last_polled_at": func.now()}

        if error:
            values["poll_error_count"] = raw_feeds.c.poll_error_count + 1
        else:
            values["poll_error_count"] = 0

        await conn.execute(
            update(raw_feeds).where(raw_feeds.c.id == raw_feed_id).values(**values)
        )

    async def get_web_feeds_due_for_poll(
        self,
        conn: AsyncConnection,
        tier_intervals: dict[str, int],
    ) -> list[dict[str, Any]]:
        """Get WEBSITE feeds that are due for polling based on their tier."""
        now = datetime.now(timezone.utc)
        all_feeds: list[dict[str, Any]] = []

        for tier_value, interval_seconds in tier_intervals.items():
            cutoff = now - timedelta(seconds=interval_seconds)
            query = (
                select(raw_feeds)
                .where(
                    raw_feeds.c.raw_type == RawType.WEBSITE,
                    raw_feeds.c.polling_tier == tier_value,
                )
                .where(
                    (raw_feeds.c.last_polled_at.is_(None))
                    | (raw_feeds.c.last_polled_at < cutoff)
                )
            )
            result = await conn.execute(query)
            all_feeds.extend(dict(row._mapping) for row in result.fetchall())

        return all_feeds

    async def update_last_execution(
        self, conn: AsyncConnection, raw_feed_id: UUID
    ) -> None:
        """Update last_execution timestamp for a raw_feed.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed
        """
        query = (
            update(raw_feeds)
            .where(raw_feeds.c.id == raw_feed_id)
            .values(last_execution=func.now())
        )

        await conn.execute(query)
        logger.debug(f"Updated last_execution for raw_feed {raw_feed_id}")

    async def get_by_id(
        self, conn: AsyncConnection, raw_feed_id: UUID
    ) -> dict[str, Any]:
        """Get raw_feed by ID.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed

        Returns:
            Dictionary containing raw_feed data

        Raises:
            ValueError: If raw_feed not found
        """
        query = select(raw_feeds).where(raw_feeds.c.id == raw_feed_id)
        result = await conn.execute(query)
        row = result.fetchone()

        if not row:
            raise ValueError(f"Raw feed {raw_feed_id} not found")

        return dict(row._mapping)

    async def get_by_telegram_username(
        self, conn: AsyncConnection, telegram_username: str
    ) -> dict[str, Any] | None:
        """Get raw_feed by Telegram username.

        Args:
            conn: Database connection
            telegram_username: Channel @username (without @)

        Returns:
            Dictionary containing raw_feed data or None if not found
        """
        telegram_username = normalize_telegram_username(telegram_username) or ""

        query = select(raw_feeds).where(
            raw_feeds.c.telegram_username == telegram_username
        )
        result = await conn.execute(query)
        row = result.fetchone()

        if row:
            return dict(row._mapping)
        return None

    async def link_prompt_to_raw_feed(
        self, conn: AsyncConnection, prompt_id: UUID, raw_feed_id: UUID
    ) -> dict[str, Any] | None:
        """Link a prompt to a raw_feed via prompts_raw_feeds junction table.

        Uses ON CONFLICT DO NOTHING to safely handle duplicate links.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt
            raw_feed_id: ID of the raw_feed

        Returns:
            Dictionary containing the created junction record, or None if link exists
        """
        from sqlalchemy.dialects.postgresql import insert as pg_insert

        query = (
            pg_insert(prompts_raw_feeds)
            .values(prompt_id=prompt_id, raw_feed_id=raw_feed_id)
            .on_conflict_do_nothing(index_elements=["prompt_id", "raw_feed_id"])
            .returning(prompts_raw_feeds)
        )

        result = await conn.execute(query)
        row = result.fetchone()

        if row is None:
            logger.debug(
                f"Link already exists: prompt {prompt_id} -> raw_feed {raw_feed_id}"
            )
            return None

        logger.info(f"Linked prompt {prompt_id} to raw_feed {raw_feed_id}")
        return dict(row._mapping)
