"""Repository for prompt-raw_feed offset tracking."""

from uuid import UUID

from loguru import logger
from sqlalchemy import func, insert, select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import prompts_raw_feeds_offsets


class PromptRawFeedOffsetRepository:
    """Repository for tracking last processed raw_post per prompt-raw_feed pair."""

    async def get_offset(
        self, conn: AsyncConnection, prompt_id: UUID, raw_feed_id: UUID
    ) -> UUID | None:
        """Get last processed raw_post_id for given prompt-raw_feed pair.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt
            raw_feed_id: ID of the raw_feed

        Returns:
            UUID of last processed raw_post, or None if no offset exists
        """
        query = select(prompts_raw_feeds_offsets.c.last_processed_raw_post_id).where(
            (prompts_raw_feeds_offsets.c.prompt_id == prompt_id)
            & (prompts_raw_feeds_offsets.c.raw_feed_id == raw_feed_id)
        )

        result = await conn.execute(query)
        row = result.fetchone()

        if row is None:
            return None

        # Cast to UUID since we know this column is UUID type
        last_processed_id: UUID | None = row[0]
        return last_processed_id  # last_processed_raw_post_id

    async def upsert_offset(
        self,
        conn: AsyncConnection,
        prompt_id: UUID,
        raw_feed_id: UUID,
        last_processed_raw_post_id: UUID,
    ) -> None:
        """Create or update offset for prompt-raw_feed pair.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt
            raw_feed_id: ID of the raw_feed
            last_processed_raw_post_id: ID of the last processed raw_post
        """
        # Try to update existing record
        update_query = (
            update(prompts_raw_feeds_offsets)
            .where(
                (prompts_raw_feeds_offsets.c.prompt_id == prompt_id)
                & (prompts_raw_feeds_offsets.c.raw_feed_id == raw_feed_id)
            )
            .values(
                last_processed_raw_post_id=last_processed_raw_post_id,
                updated_at=func.now(),
            )
        )

        result = await conn.execute(update_query)

        # If no rows updated, insert new record
        if result.rowcount == 0:
            insert_query = insert(prompts_raw_feeds_offsets).values(
                prompt_id=prompt_id,
                raw_feed_id=raw_feed_id,
                last_processed_raw_post_id=last_processed_raw_post_id,
            )
            await conn.execute(insert_query)
            logger.debug(
                f"Created new offset: prompt={prompt_id}, raw_feed={raw_feed_id}, "
                f"last_post={last_processed_raw_post_id}"
            )
        else:
            logger.debug(
                f"Updated offset: prompt={prompt_id}, raw_feed={raw_feed_id}, "
                f"last_post={last_processed_raw_post_id}"
            )

    async def get_all_offsets_for_prompt(
        self, conn: AsyncConnection, prompt_id: UUID
    ) -> dict[UUID, UUID | None]:
        """Get all offsets for a given prompt across all raw_feeds.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt

        Returns:
            Dictionary mapping raw_feed_id to last_processed_raw_post_id
        """
        query = select(
            prompts_raw_feeds_offsets.c.raw_feed_id,
            prompts_raw_feeds_offsets.c.last_processed_raw_post_id,
        ).where(prompts_raw_feeds_offsets.c.prompt_id == prompt_id)

        result = await conn.execute(query)
        rows = result.fetchall()

        return {row[0]: row[1] for row in rows}
