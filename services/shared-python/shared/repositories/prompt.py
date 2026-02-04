"""Prompt repository for database operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import pre_prompts, prompts, prompts_raw_feeds
from shared.enums import PrePromptType


class PromptRepository:
    """Repository for prompt-related database operations."""

    async def get_single_post_prompts_with_sources(
        self, conn: AsyncConnection
    ) -> list[dict[str, Any]]:
        """Get all prompts with single post type along with their sources.

        Args:
            conn: Database connection

        Returns:
            List of dictionaries containing prompt data with sources
        """
        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.sources,
            )
            .select_from(
                prompts.join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(pre_prompts.c.type == PrePromptType.SINGLE_POST)
        )
        result = await conn.execute(query)
        rows = result.fetchall()
        return [dict(row._mapping) for row in rows]

    async def get_summary_prompts_with_sources(
        self, conn: AsyncConnection
    ) -> list[dict[str, Any]]:
        """Get all prompts with summary type along with their sources.

        Args:
            conn: Database connection

        Returns:
            List of dictionaries containing prompt data with sources and digest interval
        """
        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.digest_interval_hours,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.sources,
            )
            .select_from(
                prompts.join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(pre_prompts.c.type == PrePromptType.DIGEST)
        )
        result = await conn.execute(query)
        rows = result.fetchall()
        return [dict(row._mapping) for row in rows]

    async def get_prompt_with_sources_by_id(
        self, conn: AsyncConnection, prompt_id: UUID, for_update: bool = False
    ) -> dict[str, Any] | None:
        """Get a single prompt with its type and sources by ID.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt to fetch
            for_update: If True, lock the row for update (prevents concurrent processing)

        Returns:
            Dictionary containing prompt data with sources and type, or None if not found
        """
        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.sources,
                pre_prompts.c.type,
            )
            .select_from(
                prompts.join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(prompts.c.id == prompt_id)
        )
        if for_update:
            query = query.with_for_update()
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def get_prompts_by_raw_feed_id(
        self, conn: AsyncConnection, raw_feed_id: UUID
    ) -> list[dict[str, Any]]:
        """Get all prompts associated with a raw_feed_id.

        Args:
            conn: Database connection
            raw_feed_id: ID of the raw feed

        Returns:
            List of dictionaries containing prompt data with type
        """
        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.digest_interval_hours,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.type,
            )
            .select_from(
                prompts_raw_feeds.join(
                    prompts, prompts_raw_feeds.c.prompt_id == prompts.c.id
                ).join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(prompts_raw_feeds.c.raw_feed_id == raw_feed_id)
        )
        result = await conn.execute(query)
        rows = result.fetchall()
        return [dict(row._mapping) for row in rows]

    async def update_prompt_execution_time(
        self, conn: AsyncConnection, prompt_id: UUID
    ) -> None:
        """Update the last execution time for a prompt.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt to update
        """
        query = (
            update(prompts)
            .where(prompts.c.id == prompt_id)
            .values(last_execution=func.now())
        )
        await conn.execute(query)

    async def get_next_prompt_for_background_processing(
        self, conn: AsyncConnection, preferred_type: PrePromptType
    ) -> dict[str, Any] | None:
        """Get next prompt to process for background processing.

        Filters prompts by minimum interval since last execution:
        - SINGLE_POST: 2 minutes
        - DIGEST: digest_interval_hours (default 12h)

        Selects oldest last_execution (or NULL) within the type.

        Args:
            conn: Database connection
            preferred_type: Preferred prompt type (SINGLE_POST, DIGEST)

        Returns:
            Dictionary containing prompt data or None if no prompts available
        """
        now = func.now()

        # Build interval condition based on type
        if preferred_type == PrePromptType.DIGEST:
            # For DIGEST: use digest_interval_hours (default 12h if NULL)
            # Condition: last_execution IS NULL OR (NOW() - last_execution) > INTERVAL '1 hour' * COALESCE(digest_interval_hours, 12)
            interval_condition = (prompts.c.last_execution.is_(None)) | (
                now - prompts.c.last_execution
                > func.make_interval(
                    0, 0, 0, 0, func.coalesce(prompts.c.digest_interval_hours, 12)
                )
            )
        else:
            # For SINGLE_POST: 2 minutes interval
            # Condition: last_execution IS NULL OR (NOW() - last_execution) > INTERVAL '2 minutes'
            interval_condition = (prompts.c.last_execution.is_(None)) | (
                now - prompts.c.last_execution > func.make_interval(0, 0, 0, 0, 0, 2)
            )

        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.digest_interval_hours,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.sources,
                pre_prompts.c.type,
            )
            .select_from(
                prompts.join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(pre_prompts.c.type == preferred_type)
            .where(interval_condition)
            .order_by(prompts.c.last_execution.asc().nullsfirst())
            .limit(1)
            .with_for_update(skip_locked=True)
        )

        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def get_prompt_by_feed_id(
        self, conn: AsyncConnection, feed_id: UUID
    ) -> dict[str, Any] | None:
        """Get a prompt by its associated feed_id.

        Args:
            conn: Database connection
            feed_id: ID of the feed

        Returns:
            Dictionary containing prompt data with type, or None if not found
        """
        query = (
            select(
                prompts.c.id.label("prompt_id"),
                prompts.c.prompt,
                prompts.c.raw_prompt,
                prompts.c.last_execution,
                prompts.c.feed_id,
                prompts.c.digest_interval_hours,
                prompts.c.views_config,
                prompts.c.filters_config,
                pre_prompts.c.type,
            )
            .select_from(
                prompts.join(pre_prompts, prompts.c.pre_prompt_id == pre_prompts.c.id)
            )
            .where(prompts.c.feed_id == feed_id)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def update_prompt_instruction(
        self, conn: AsyncConnection, prompt_id: UUID, instruction: str
    ) -> None:
        """Update prompt instruction (raw_prompt).

        Args:
            conn: Database connection
            prompt_id: ID of the prompt to update
            instruction: New instruction text
        """
        query = (
            update(prompts)
            .where(prompts.c.id == prompt_id)
            .values(raw_prompt=instruction)
        )
        await conn.execute(query)

    async def update_digest_interval(
        self, conn: AsyncConnection, prompt_id: UUID, hours: int
    ) -> None:
        """Update digest_interval_hours for DIGEST feeds.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt to update
            hours: New interval in hours (1-48)
        """
        query = (
            update(prompts)
            .where(prompts.c.id == prompt_id)
            .values(digest_interval_hours=hours)
        )
        await conn.execute(query)

    async def replace_prompt_sources(
        self, conn: AsyncConnection, prompt_id: UUID, raw_feed_ids: list[UUID]
    ) -> None:
        """Replace all sources linked to prompt.

        Deletes existing links and creates new ones.

        Args:
            conn: Database connection
            prompt_id: ID of the prompt
            raw_feed_ids: List of raw_feed IDs to link
        """
        from sqlalchemy import delete, insert

        # Delete existing links
        delete_query = delete(prompts_raw_feeds).where(
            prompts_raw_feeds.c.prompt_id == prompt_id
        )
        await conn.execute(delete_query)

        # Insert new links
        if raw_feed_ids:
            values = [
                {"prompt_id": prompt_id, "raw_feed_id": raw_feed_id}
                for raw_feed_id in raw_feed_ids
            ]
            insert_query = insert(prompts_raw_feeds).values(values)
            await conn.execute(insert_query)
