from datetime import datetime
from typing import Any
from uuid import UUID

from loguru import logger
from sqlalchemy import insert, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import prompts_raw_feeds, raw_feeds, raw_posts


class RawPostRepository:
    """Repository for raw_posts table operations."""

    async def create_raw_post(
        self,
        conn: AsyncConnection,
        raw_feed_id: UUID,
        content: str,
        title: str,
        media_objects: list[dict[str, Any]],
        telegram_message_id: int,
        telegram_chat_id: int,
        media_group_id: str | None = None,
        created_at: datetime | None = None,
        moderation_action: str | None = None,
        moderation_labels: list[str] | None = None,
        moderation_block_reasons: list[str] | None = None,
        moderation_checked_at: datetime | None = None,
        moderation_matched_entities: list[str] | None = None,
    ) -> dict[str, Any]:
        """Create a raw post from Telegram message.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed
            content: Post text content
            title: Post title
            media_objects: List of media object dictionaries (JSON-serializable)
            telegram_message_id: Telegram message ID
            telegram_chat_id: Telegram chat ID
            media_group_id: Optional Telegram album ID for grouping
            created_at: Optional datetime for when the message was created (Telegram date)
            moderation_action: Optional moderation action (pass, block, label, review)
            moderation_labels: Optional list of content labels
            moderation_block_reasons: Optional list of block reasons
            moderation_checked_at: Optional timestamp when moderation was performed
            moderation_matched_entities: Optional list of matched entity names

        Returns:
            Dictionary containing created raw_post data

        Raises:
            ValueError: If telegram_chat_id is None (required for unique code generation)
        """
        if telegram_chat_id is None:
            logger.warning(
                f"Skipping raw_post creation: telegram_chat_id is None "
                f"for message {telegram_message_id}, raw_feed_id={raw_feed_id}"
            )
            raise ValueError(
                f"telegram_chat_id is required for raw_post creation, "
                f"message_id={telegram_message_id}"
            )

        # Use media_group_id for unique code if available (more reliable for albums)
        if media_group_id:
            rp_unique_code = f"tg_{telegram_chat_id}_{media_group_id}"
        else:
            rp_unique_code = f"tg_{telegram_chat_id}_{telegram_message_id}"

        # Build values dict
        values = {
            "raw_feed_id": raw_feed_id,
            "content": content,
            "title": title,
            "media_objects": media_objects,  # JSONB field
            "rp_unique_code": rp_unique_code,
            "media_group_id": media_group_id,
            "telegram_message_id": telegram_message_id,  # Store actual message ID
        }

        # Add created_at if provided (otherwise DB will use server_default)
        if created_at is not None:
            values["created_at"] = created_at

        # Add moderation fields if provided
        if moderation_action is not None:
            values["moderation_action"] = moderation_action
        if moderation_labels is not None:
            values["moderation_labels"] = moderation_labels
        if moderation_block_reasons is not None:
            values["moderation_block_reasons"] = moderation_block_reasons
        if moderation_checked_at is not None:
            values["moderation_checked_at"] = moderation_checked_at
        if moderation_matched_entities is not None:
            values["moderation_matched_entities"] = moderation_matched_entities

        query = insert(raw_posts).values(**values).returning(raw_posts)

        result = await conn.execute(query)
        row = result.fetchone()

        if row is None:
            raise ValueError(
                f"Failed to create raw_post for message {telegram_message_id}"
            )

        logger.debug(
            f"Created raw_post {row._mapping['id']} for message {telegram_message_id}"
        )
        return dict(row._mapping)

    async def create_rss_raw_post(
        self,
        conn: AsyncConnection,
        raw_feed_id: UUID,
        content: str,
        title: str,
        media_objects: list[dict[str, Any]],
        rp_unique_code: str,
        media_group_id: str | None = None,
        created_at: datetime | None = None,
        source_url: str | None = None,
        moderation_action: str | None = None,
        moderation_labels: list[str] | None = None,
        moderation_block_reasons: list[str] | None = None,
        moderation_checked_at: datetime | None = None,
        moderation_matched_entities: list[str] | None = None,
    ) -> dict[str, Any]:
        """Create a raw post from RSS/Web article.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed
            content: Article text content
            title: Article title
            media_objects: List of media object dictionaries (JSON-serializable)
            rp_unique_code: Unique code for deduplication (MD5 hash of URL)
            media_group_id: Optional media group ID for grouping (usually None for RSS)
            created_at: Optional datetime for when the article was published
            source_url: Optional source URL for the article (for creating source records)
            moderation_action: Optional moderation action (pass, block, label, review)
            moderation_labels: Optional list of content labels
            moderation_block_reasons: Optional list of block reasons
            moderation_checked_at: Optional timestamp when moderation was performed
            moderation_matched_entities: Optional list of matched entity names

        Returns:
            Dictionary containing created raw_post data
        """
        # Build values dict
        values = {
            "raw_feed_id": raw_feed_id,
            "content": content,
            "title": title,
            "media_objects": media_objects,  # JSONB field
            "rp_unique_code": rp_unique_code,
            "media_group_id": media_group_id,
            "telegram_message_id": None,  # Not applicable for RSS
            "source_url": source_url,
        }

        # Add created_at if provided (otherwise DB will use server_default)
        if created_at is not None:
            values["created_at"] = created_at

        # Add moderation fields if provided
        if moderation_action is not None:
            values["moderation_action"] = moderation_action
        if moderation_labels is not None:
            values["moderation_labels"] = moderation_labels
        if moderation_block_reasons is not None:
            values["moderation_block_reasons"] = moderation_block_reasons
        if moderation_checked_at is not None:
            values["moderation_checked_at"] = moderation_checked_at
        if moderation_matched_entities is not None:
            values["moderation_matched_entities"] = moderation_matched_entities

        query = insert(raw_posts).values(**values).returning(raw_posts)

        result = await conn.execute(query)
        row = result.fetchone()

        if row is None:
            raise ValueError(f"Failed to create raw_post for RSS article {title}")

        logger.debug(f"Created RSS raw_post {row._mapping['id']} for article {title}")
        return dict(row._mapping)

    async def upsert_rss_raw_post(
        self,
        conn: AsyncConnection,
        raw_feed_id: UUID,
        content: str,
        title: str,
        media_objects: list[dict[str, Any]],
        rp_unique_code: str,
        media_group_id: str | None = None,
        created_at: datetime | None = None,
        source_url: str | None = None,
        moderation_action: str | None = None,
        moderation_labels: list[str] | None = None,
        moderation_block_reasons: list[str] | None = None,
        moderation_checked_at: datetime | None = None,
        moderation_matched_entities: list[str] | None = None,
    ) -> dict[str, Any]:
        """Insert or update RSS/Web raw_post (UPSERT).

        If a post with the same rp_unique_code exists, it will be updated.
        Otherwise, a new post will be created.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed
            content: Article text content
            title: Article title
            media_objects: List of media object dictionaries (JSON-serializable)
            rp_unique_code: Unique code for deduplication (MD5 hash of URL)
            media_group_id: Optional media group ID for grouping (usually None for RSS)
            created_at: Optional datetime for when the article was published
            source_url: Optional source URL for the article (for creating source records)
            moderation_action: Optional moderation action (pass, block, label, review)
            moderation_labels: Optional list of content labels
            moderation_block_reasons: Optional list of block reasons
            moderation_checked_at: Optional timestamp when moderation was performed
            moderation_matched_entities: Optional list of matched entity names

        Returns:
            Dictionary containing created/updated raw_post data
        """
        # Build values dict
        values = {
            "raw_feed_id": raw_feed_id,
            "content": content,
            "title": title,
            "media_objects": media_objects,  # JSONB field
            "rp_unique_code": rp_unique_code,
            "media_group_id": media_group_id,
            "telegram_message_id": None,  # Not applicable for RSS
            "source_url": source_url,
        }

        # Add created_at if provided (otherwise DB will use server_default)
        if created_at is not None:
            values["created_at"] = created_at

        # Add moderation fields if provided
        if moderation_action is not None:
            values["moderation_action"] = moderation_action
        if moderation_labels is not None:
            values["moderation_labels"] = moderation_labels
        if moderation_block_reasons is not None:
            values["moderation_block_reasons"] = moderation_block_reasons
        if moderation_checked_at is not None:
            values["moderation_checked_at"] = moderation_checked_at
        if moderation_matched_entities is not None:
            values["moderation_matched_entities"] = moderation_matched_entities

        # PostgreSQL INSERT ... ON CONFLICT ... DO UPDATE
        insert_stmt = pg_insert(raw_posts).values(**values)

        # On conflict, update all fields except id, created_at, rp_unique_code
        upsert_stmt = insert_stmt.on_conflict_do_update(
            index_elements=["rp_unique_code"],
            set_={
                "raw_feed_id": insert_stmt.excluded.raw_feed_id,
                "content": insert_stmt.excluded.content,
                "title": insert_stmt.excluded.title,
                "media_objects": insert_stmt.excluded.media_objects,
                "media_group_id": insert_stmt.excluded.media_group_id,
                "source_url": insert_stmt.excluded.source_url,
                "moderation_action": insert_stmt.excluded.moderation_action,
                "moderation_labels": insert_stmt.excluded.moderation_labels,
                "moderation_block_reasons": insert_stmt.excluded.moderation_block_reasons,
                "moderation_checked_at": insert_stmt.excluded.moderation_checked_at,
                "moderation_matched_entities": insert_stmt.excluded.moderation_matched_entities,
                # Don't update created_at - keep original timestamp
            },
        )

        stmt = upsert_stmt.returning(raw_posts)

        result = await conn.execute(stmt)
        row = result.fetchone()

        if row is None:
            raise ValueError(f"Failed to upsert raw_post for RSS article {title}")

        logger.debug(f"Upserted RSS raw_post {row._mapping['id']} for article {title}")
        return dict(row._mapping)

    async def post_exists(
        self,
        conn: AsyncConnection,
        telegram_chat_id: int,
        telegram_message_id: int,
        media_group_id: str | None = None,
    ) -> bool:
        """Check if a raw_post already exists for a Telegram message.

        Args:
            conn: Database connection
            telegram_chat_id: Telegram chat ID
            telegram_message_id: Telegram message ID
            media_group_id: Optional Telegram album ID

        Returns:
            True if post exists, False otherwise
        """
        # Check by media_group_id first (more reliable for albums)
        if media_group_id:
            rp_unique_code = f"tg_{telegram_chat_id}_{media_group_id}"
        else:
            rp_unique_code = f"tg_{telegram_chat_id}_{telegram_message_id}"

        query = select(raw_posts.c.id).where(
            raw_posts.c.rp_unique_code == rp_unique_code
        )
        result = await conn.execute(query)
        return result.fetchone() is not None

    async def rss_post_exists(
        self,
        conn: AsyncConnection,
        rp_unique_code: str,
    ) -> bool:
        """Check if a raw_post already exists for an RSS/Web article.

        Args:
            conn: Database connection
            rp_unique_code: Unique code for the article (MD5 hash of URL)

        Returns:
            True if post exists, False otherwise
        """
        query = select(raw_posts.c.id).where(
            raw_posts.c.rp_unique_code == rp_unique_code
        )
        result = await conn.execute(query)
        return result.fetchone() is not None

    async def batch_check_rss_posts_exist(
        self,
        conn: AsyncConnection,
        rp_unique_codes: list[str],
    ) -> set[str]:
        """Check which RSS/Web articles already exist (batch operation).

        Optimized for checking multiple posts in a single query instead of N queries.

        Args:
            conn: Database connection
            rp_unique_codes: List of unique codes to check

        Returns:
            Set of unique codes that exist in the database
        """
        if not rp_unique_codes:
            return set()

        query = select(raw_posts.c.rp_unique_code).where(
            raw_posts.c.rp_unique_code.in_(rp_unique_codes)
        )
        result = await conn.execute(query)
        return {row[0] for row in result.fetchall()}

    async def batch_create_rss_raw_posts(
        self,
        conn: AsyncConnection,
        posts_data: list[dict[str, Any]],
    ) -> list[UUID]:
        """Create multiple RSS/Web raw posts in a single batch operation.

        Optimized for creating multiple posts in a single query instead of N queries.

        Args:
            conn: Database connection
            posts_data: List of dictionaries with post data. Each dict must contain:
                - raw_feed_id: UUID
                - content: str
                - title: str
                - media_objects: List[Dict]
                - rp_unique_code: str
                - media_group_id: Optional[str]
                - source_url: Optional[str]
                - created_at: Optional[datetime]
                - moderation_action: Optional[str]
                - moderation_labels: Optional[List[str]]
                - moderation_block_reasons: Optional[List[str]]
                - moderation_checked_at: Optional[datetime]
                - moderation_matched_entities: Optional[List[str]]

        Returns:
            List of created raw_post UUIDs

        Raises:
            ValueError: If no posts were created
        """
        if not posts_data:
            return []

        # Normalize data for insert
        values_list = []
        for post in posts_data:
            values = {
                "raw_feed_id": post["raw_feed_id"],
                "content": post["content"],
                "title": post["title"],
                "media_objects": post["media_objects"],
                "rp_unique_code": post["rp_unique_code"],
                "media_group_id": post.get("media_group_id"),
                "telegram_message_id": None,  # Not applicable for RSS
                "source_url": post.get("source_url"),
            }

            # Add created_at if provided
            if "created_at" in post and post["created_at"] is not None:
                values["created_at"] = post["created_at"]

            # Add moderation fields if provided
            if post.get("moderation_action") is not None:
                values["moderation_action"] = post["moderation_action"]
            if post.get("moderation_labels") is not None:
                values["moderation_labels"] = post["moderation_labels"]
            if post.get("moderation_block_reasons") is not None:
                values["moderation_block_reasons"] = post["moderation_block_reasons"]
            if post.get("moderation_checked_at") is not None:
                values["moderation_checked_at"] = post["moderation_checked_at"]
            if post.get("moderation_matched_entities") is not None:
                values["moderation_matched_entities"] = post[
                    "moderation_matched_entities"
                ]

            values_list.append(values)

        # Batch insert with ON CONFLICT to handle race conditions
        query = (
            pg_insert(raw_posts)
            .values(values_list)
            .on_conflict_do_nothing(index_elements=["rp_unique_code"])
            .returning(raw_posts.c.id)
        )

        result = await conn.execute(query)
        rows = result.fetchall()

        created_ids = [row[0] for row in rows]
        logger.debug(
            f"Batch insert RSS: {len(created_ids)}/{len(posts_data)} created "
            f"({len(posts_data) - len(created_ids)} duplicates skipped)"
        )

        return created_ids

    async def batch_create_telegram_raw_posts(
        self,
        conn: AsyncConnection,
        posts_data: list[dict[str, Any]],
    ) -> list[UUID]:
        """Create multiple Telegram raw posts in a single batch operation.

        Optimized for creating multiple posts in a single query instead of N queries.

        Args:
            conn: Database connection
            posts_data: List of dictionaries with post data. Each dict must contain:
                - raw_feed_id: UUID
                - content: str
                - title: str
                - media_objects: List[Dict]
                - telegram_message_id: int
                - telegram_chat_id: int
                - media_group_id: Optional[str]
                - created_at: Optional[datetime]
                - moderation_action: Optional[str]
                - moderation_labels: Optional[List[str]]
                - moderation_block_reasons: Optional[List[str]]
                - moderation_checked_at: Optional[datetime]
                - moderation_matched_entities: Optional[List[str]]

        Returns:
            List of created raw_post UUIDs

        Raises:
            ValueError: If no posts were created
        """
        if not posts_data:
            return []

        values_list = []
        skipped_count = 0
        for post in posts_data:
            telegram_chat_id = post["telegram_chat_id"]
            telegram_message_id = post["telegram_message_id"]
            media_group_id = post.get("media_group_id")

            if telegram_chat_id is None:
                logger.warning(
                    f"Skipping post with None telegram_chat_id: "
                    f"message_id={telegram_message_id}, raw_feed_id={post['raw_feed_id']}"
                )
                skipped_count += 1
                continue

            if media_group_id:
                rp_unique_code = f"tg_{telegram_chat_id}_{media_group_id}"
            else:
                rp_unique_code = f"tg_{telegram_chat_id}_{telegram_message_id}"

            values = {
                "raw_feed_id": post["raw_feed_id"],
                "content": post["content"],
                "title": post["title"],
                "media_objects": post["media_objects"],
                "rp_unique_code": rp_unique_code,
                "media_group_id": media_group_id,
                "telegram_message_id": telegram_message_id,
            }

            if "created_at" in post and post["created_at"] is not None:
                values["created_at"] = post["created_at"]

            # Add moderation fields if provided
            if post.get("moderation_action") is not None:
                values["moderation_action"] = post["moderation_action"]
            if post.get("moderation_labels") is not None:
                values["moderation_labels"] = post["moderation_labels"]
            if post.get("moderation_block_reasons") is not None:
                values["moderation_block_reasons"] = post["moderation_block_reasons"]
            if post.get("moderation_checked_at") is not None:
                values["moderation_checked_at"] = post["moderation_checked_at"]
            if post.get("moderation_matched_entities") is not None:
                values["moderation_matched_entities"] = post[
                    "moderation_matched_entities"
                ]

            values_list.append(values)

        if not values_list:
            logger.debug(
                f"Batch insert Telegram: all {len(posts_data)} posts skipped "
                f"({skipped_count} with None telegram_chat_id)"
            )
            return []

        # Batch insert with ON CONFLICT to handle race conditions
        query = (
            pg_insert(raw_posts)
            .values(values_list)
            .on_conflict_do_nothing(index_elements=["rp_unique_code"])
            .returning(raw_posts.c.id)
        )

        result = await conn.execute(query)
        rows = result.fetchall()

        created_ids = [row[0] for row in rows]
        duplicates_skipped = len(values_list) - len(created_ids)
        logger.debug(
            f"Batch insert Telegram: {len(created_ids)}/{len(posts_data)} created "
            f"({duplicates_skipped} duplicates, {skipped_count} None chat_id skipped)"
        )

        return created_ids

    async def _offset_table_exists(self, conn: AsyncConnection) -> bool:
        """Check if prompts_raw_feeds_offsets table exists.

        Some environments (e.g. older databases, condensed tests) might miss the table.
        In that case we gracefully fall back to timestamp-based filtering.
        """
        try:
            result = await conn.execute(
                text(
                    "SELECT EXISTS (SELECT FROM information_schema.tables "
                    "WHERE table_schema = :schema AND table_name = :table_name)"
                ),
                {"schema": "public", "table_name": "prompts_raw_feeds_offsets"},
            )
            return bool(result.scalar())
        except Exception as exc:
            logger.warning(
                f"Failed to detect prompts_raw_feeds_offsets table: {exc}. "
                "Falling back to timestamp-based filtering."
            )
            await conn.rollback()
            return False

    async def _get_raw_posts_with_offsets(
        self,
        conn: AsyncConnection,
        prompt_id: UUID,
        last_execution: datetime | None,
        limit: int | None,
    ) -> list[dict[str, Any]]:
        """Get raw posts using offset-based filtering."""
        from sqlalchemy import or_
        from sqlalchemy.sql.expression import ColumnElement

        from shared.database.tables import prompts_raw_feeds_offsets

        offset_timestamps_cte = (
            select(
                prompts_raw_feeds_offsets.c.raw_feed_id,
                raw_posts.c.created_at.label("last_processed_at"),
            )
            .select_from(
                prompts_raw_feeds_offsets.join(
                    raw_posts,
                    prompts_raw_feeds_offsets.c.last_processed_raw_post_id
                    == raw_posts.c.id,
                )
            )
            .where(prompts_raw_feeds_offsets.c.prompt_id == prompt_id)
            .cte("offset_timestamps")
        )

        query = (
            select(
                raw_posts,
                raw_feeds.c.telegram_username,
            )
            .select_from(
                prompts_raw_feeds.join(
                    raw_feeds, prompts_raw_feeds.c.raw_feed_id == raw_feeds.c.id
                )
                .join(raw_posts, raw_posts.c.raw_feed_id == raw_feeds.c.id)
                .outerjoin(
                    offset_timestamps_cte,
                    offset_timestamps_cte.c.raw_feed_id == raw_feeds.c.id,
                )
            )
            .where(prompts_raw_feeds.c.prompt_id == prompt_id)
            .where(
                (raw_posts.c.moderation_action.is_(None))
                | (raw_posts.c.moderation_action != "block")
            )
        )

        filter_conditions: list[ColumnElement[bool]] = [
            (offset_timestamps_cte.c.last_processed_at.isnot(None))
            & (raw_posts.c.created_at > offset_timestamps_cte.c.last_processed_at),
        ]

        if last_execution is not None:
            filter_conditions.append(
                (offset_timestamps_cte.c.last_processed_at.is_(None))
                & (raw_posts.c.created_at > last_execution)
            )
        else:
            filter_conditions.append(
                offset_timestamps_cte.c.last_processed_at.is_(None)
            )

        query = query.where(or_(*filter_conditions)).order_by(
            raw_posts.c.created_at.desc()
        )

        if limit is not None:
            query = query.limit(limit)

        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def _get_raw_posts_by_timestamp(
        self,
        conn: AsyncConnection,
        prompt_id: UUID,
        last_execution: datetime | None,
        limit: int | None,
    ) -> list[dict[str, Any]]:
        """Get raw posts using timestamp-based filtering."""
        query = (
            select(
                raw_posts,
                raw_feeds.c.telegram_username,
            )
            .select_from(
                prompts_raw_feeds.join(
                    raw_feeds, prompts_raw_feeds.c.raw_feed_id == raw_feeds.c.id
                ).join(raw_posts, raw_posts.c.raw_feed_id == raw_feeds.c.id)
            )
            .where(prompts_raw_feeds.c.prompt_id == prompt_id)
            .where(
                (raw_posts.c.moderation_action.is_(None))
                | (raw_posts.c.moderation_action != "block")
            )
        )

        if last_execution:
            query = query.where(raw_posts.c.created_at > last_execution)

        query = query.order_by(raw_posts.c.created_at.desc())

        if limit is not None:
            query = query.limit(limit)

        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_raw_posts_by_prompt(
        self,
        conn: AsyncConnection,
        prompt_id: UUID,
        last_execution: datetime | None,
        limit: int | None = None,
        use_offsets: bool = True,
    ) -> list[dict[str, Any]]:
        """Get raw_posts for a prompt using offset-based or timestamp-based filtering.

        This method joins prompts_raw_feeds -> raw_feeds -> raw_posts
        and uses prompts_raw_feeds_offsets for granular per-source tracking.

        Filtering logic (in order of priority per raw_feed):
        1. If offset exists for raw_feed: filter by last_processed_post's created_at
        2. Else if last_execution provided: filter by last_execution timestamp
        3. Else: return all posts

        Args:
            conn: Database connection
            prompt_id: ID of the prompt
            last_execution: Fallback timestamp filter (for backward compatibility)
            limit: Maximum number of posts to return. If None, returns all.
            use_offsets: Whether to use offset-based filtering (default True)

        Returns:
            List of dictionaries containing raw_post data with telegram_username, raw_feed_id
        """
        if use_offsets and await self._offset_table_exists(conn):
            try:
                return await self._get_raw_posts_with_offsets(
                    conn, prompt_id, last_execution, limit
                )
            except Exception as e:
                logger.warning(
                    f"Failed to use offset-based filtering: {e}. "
                    "Falling back to timestamp-based filtering."
                )

        return await self._get_raw_posts_by_timestamp(
            conn, prompt_id, last_execution, limit
        )

    async def get_by_id(
        self, conn: AsyncConnection, raw_post_id: UUID
    ) -> dict[str, Any]:
        """Get raw_post by ID.

        Args:
            conn: Database connection
            raw_post_id: ID of the raw_post

        Returns:
            Dictionary containing raw_post data

        Raises:
            ValueError: If raw_post not found
        """
        query = select(raw_posts).where(raw_posts.c.id == raw_post_id)
        result = await conn.execute(query)
        row = result.fetchone()

        if not row:
            raise ValueError(f"Raw post {raw_post_id} not found")

        return dict(row._mapping)

    async def get_by_raw_feed(
        self,
        conn: AsyncConnection,
        raw_feed_id: UUID,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        """Get all raw_posts for a raw_feed.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw_feed
            limit: Maximum number of posts to return
            offset: Number of posts to skip (for pagination)

        Returns:
            List of dictionaries containing raw_post data
        """
        query = (
            select(raw_posts)
            .where(raw_posts.c.raw_feed_id == raw_feed_id)
            .where(
                (raw_posts.c.moderation_action.is_(None))
                | (raw_posts.c.moderation_action != "block")
            )
            .order_by(raw_posts.c.created_at.desc())
        )

        if offset > 0:
            query = query.offset(offset)

        if limit:
            query = query.limit(limit)

        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_by_telegram_usernames(
        self,
        conn: AsyncConnection,
        telegram_usernames: list[str],
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """Get raw_posts by multiple telegram usernames.

        Args:
            conn: Database connection
            telegram_usernames: List of channel @usernames (with or without @)
            limit: Maximum number of posts to return (default 10)

        Returns:
            List of dictionaries containing raw_post data, ordered by created_at desc
        """
        normalized = [
            u.lstrip("@").lower() for u in telegram_usernames if u and u.strip()
        ]

        if not normalized:
            return []

        query = (
            select(raw_posts)
            .join(raw_feeds, raw_posts.c.raw_feed_id == raw_feeds.c.id)
            .where(raw_feeds.c.telegram_username.in_(normalized))
            .order_by(raw_posts.c.created_at.desc())
            .limit(limit)
        )

        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]
