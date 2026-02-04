from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import delete, insert, select, text, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import chats, chats_messages, pre_prompts


class ChatRepository:
    async def create_chat(self, conn: AsyncConnection, user_id: UUID) -> dict[str, Any]:
        # Создаем новый pre_prompt с дефолтными значениями
        pre_prompt_query = (
            insert(pre_prompts)
            .values()
            .returning(pre_prompts.c.id.label("pre_prompt_id"))
        )
        pre_prompt_result = await conn.execute(pre_prompt_query)
        pre_prompt_row = pre_prompt_result.fetchone()
        if pre_prompt_row is None:
            raise ValueError("Failed to create pre_prompt")
        pre_prompt_id = pre_prompt_row[0]

        # Создаем чат связанный с user_id и pre_prompt_id
        chat_query = (
            insert(chats)
            .values(user_id=user_id, pre_prompt_id=pre_prompt_id)
            .returning(chats)
        )
        chat_result = await conn.execute(chat_query)
        chat_row = chat_result.fetchone()
        if chat_row is None:
            raise ValueError("Failed to create chat")
        return dict(chat_row._mapping)

    async def delete_chat(self, conn: AsyncConnection, chat_id: UUID) -> None:
        query = delete(chats).where(chats.c.id == chat_id)
        await conn.execute(query)

    async def get_user_chats(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        """Check if user has any existing chats"""
        query = select(chats).where(chats.c.user_id == user_id)
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_all_user_chats(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        """Get all user chats with messages and pre_prompt data"""
        query = text("""
            SELECT
              chats.id AS chat_id,
              chats.created_at,
              pre_prompts.suggestions,
              pre_prompts.is_ready_to_create_feed,
              COALESCE(
                jsonb_agg(
                  to_jsonb(chats_messages)
                  ORDER BY chats_messages.sequence DESC
                ) FILTER (WHERE chats_messages.id IS NOT NULL),
                '[]'::jsonb
              ) AS messages
            FROM
              chats
            LEFT JOIN chats_messages ON chats_messages.chat_id = chats.id
            LEFT JOIN pre_prompts ON chats.pre_prompt_id = pre_prompts.id
            WHERE
              chats.user_id = :user_id
            GROUP BY
              chats.id,
              chats.created_at,
              pre_prompts.suggestions,
              pre_prompts.is_ready_to_create_feed
            ORDER BY
              MAX(chats_messages.created_at) DESC NULLS LAST,
              chats.created_at DESC;
        """)

        result = await conn.execute(query, {"user_id": user_id})
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_chat_with_pre_prompt(
        self, conn: AsyncConnection, chat_id: UUID
    ) -> dict[str, Any]:
        """Get chat data with associated pre_prompt information.

        Args:
            conn: Database connection
            chat_id: ID of the chat

        Returns:
            Dictionary containing chat and pre_prompt data

        Raises:
            ValueError: If chat not found
        """
        query = text("""
            SELECT
                chats.id as chat_id,
                chats.user_id,
                chats.pre_prompt_id,
                pre_prompts.prompt,
                pre_prompts.type as feed_type,
                pre_prompts.sources,
                pre_prompts.source_types,
                pre_prompts.type,
                pre_prompts.description,
                pre_prompts.title,
                pre_prompts.tags,
                pre_prompts.digest_interval_hours,
                pre_prompts.filters,
                pre_prompts.filter_ads,
                pre_prompts.filter_duplicates,
                pre_prompts.views_raw,
                pre_prompts.filters_raw
            FROM chats
            JOIN pre_prompts ON pre_prompts.id = chats.pre_prompt_id
            WHERE chats.id = :chat_id
        """)

        result = await conn.execute(query, {"chat_id": chat_id})
        row = result.fetchone()

        if not row:
            raise ValueError(f"Chat with id {chat_id} not found")

        return dict(row._mapping)

    async def get_chat_with_pre_prompt_and_history(
        self, conn: AsyncConnection, chat_id: UUID
    ) -> dict[str, Any]:
        """Get chat data with pre_prompt info and recent message history.

        Args:
            conn: Database connection
            chat_id: ID of the chat

        Returns:
            Dictionary containing chat, pre_prompt data, and recent messages

        Raises:
            ValueError: If chat not found
        """
        query = text("""
            SELECT
                chats.id as chat_id,
                chats.user_id,
                chats.pre_prompt_id,
                pre_prompts.prompt,
                pre_prompts.sources,
                pre_prompts.source_types,
                pre_prompts.type,
                pre_prompts.suggestions,
                pre_prompts.is_ready_to_create_feed,
                pre_prompts.filters,
                pre_prompts.filter_ads,
                pre_prompts.filter_duplicates,
                COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'message', chats_messages.message,
                            'type', chats_messages.type,
                            'created_at', chats_messages.created_at,
                            'sequence', chats_messages.sequence
                        )
                        ORDER BY chats_messages.sequence DESC
                    ) FILTER (WHERE chats_messages.id IS NOT NULL),
                    '[]'::jsonb
                ) AS messages
            FROM chats
            JOIN pre_prompts ON pre_prompts.id = chats.pre_prompt_id
            LEFT JOIN chats_messages ON chats_messages.chat_id = chats.id
            WHERE chats.id = :chat_id
            GROUP BY
                chats.id,
                chats.user_id,
                chats.pre_prompt_id,
                pre_prompts.prompt,
                pre_prompts.sources,
                pre_prompts.source_types,
                pre_prompts.type,
                pre_prompts.suggestions,
                pre_prompts.is_ready_to_create_feed,
                pre_prompts.filters,
                pre_prompts.filter_ads,
                pre_prompts.filter_duplicates
        """)

        result = await conn.execute(query, {"chat_id": chat_id})
        row = result.fetchone()

        if not row:
            raise ValueError(f"Chat with id {chat_id} not found")

        data = dict(row._mapping)

        messages = data.get("messages", [])
        if messages and len(messages) > 15:
            data["messages"] = messages[:15]

        return data

    async def insert_chat_message(
        self,
        conn: AsyncConnection,
        chat_id: UUID,
        message: str,
        message_type: str,
    ) -> dict[str, Any]:
        """Insert a new chat message.

        Args:
            conn: Database connection
            chat_id: ID of the chat
            message: Message content
            message_type: Type of message ('HUMAN' or 'AI')

        Returns:
            Dictionary containing inserted message data

        Raises:
            ValueError: If insertion fails
        """
        next_seq_subquery = (
            select(sa.func.coalesce(sa.func.max(chats_messages.c.sequence), 0) + 1)
            .where(chats_messages.c.chat_id == chat_id)
            .scalar_subquery()
        )

        query = (
            insert(chats_messages)
            .values(
                chat_id=chat_id,
                message=message,
                type=message_type,
                sequence=next_seq_subquery,
            )
            .returning(chats_messages)
        )

        result = await conn.execute(query)
        row = result.fetchone()

        if not row:
            raise ValueError("Failed to insert chat message")

        return dict(row._mapping)

    async def update_pre_prompt(
        self,
        conn: AsyncConnection,
        pre_prompt_id: UUID,
        prompt: str | None = None,
        sources: list[str] | None = None,
        source_types: dict[str, str] | None = None,
        type_value: str | None = None,
        suggestions: list[str] | None = None,
        is_ready_to_create_feed: bool | None = None,
        description: str | None = None,
        title: str | None = None,
        tags: list[str] | None = None,
        digest_interval_hours: int | None = None,
        filters: list[str] | None = None,
        filter_ads: bool | None = None,
        filter_duplicates: bool | None = None,
        views_raw: list[str] | None = None,
        filters_raw: list[str] | None = None,
    ) -> dict[str, Any]:
        """Update pre_prompt fields with collected parameters.

        Args:
            conn: Database connection
            pre_prompt_id: ID of the pre_prompt to update
            prompt: Prompt text (can be None)
            sources: List of source channels (can be None)
            source_types: Mapping of source URL to parser type (can be None)
            type_value: Feed type (can be None)
            suggestions: List of suggestions (can be None)
            is_ready_to_create_feed: Whether feed is ready to create
            description: Feed description (can be None)
            title: Feed title (can be None)
            tags: List of feed tags (can be None)
            digest_interval_hours: Interval in hours for digest generation (can be None).
                Only for SUMMARY type feeds.
            filters: List of predefined filter names (can be None).
                E.g., ["remove_ads", "remove_duplicates"]
            filter_ads: Whether to filter ads during processing (can be None).
            filter_duplicates: Whether to filter duplicate posts (can be None).
            views_raw: User-defined view descriptions (can be None).
                E.g., ["read as if I'm 5", "summarize"]
            filters_raw: User-defined filter descriptions (can be None).
                E.g., ["no ads", "only AI"]

        Returns:
            Dictionary containing updated pre_prompt data

        Raises:
            ValueError: If update fails
        """
        # Build update values, only including non-None values
        update_values: dict[str, Any] = {}

        if prompt is not None:
            update_values["prompt"] = prompt
        if sources is not None:
            update_values["sources"] = sources
        if source_types is not None:
            update_values["source_types"] = source_types
        if type_value is not None:
            update_values["type"] = type_value
        if suggestions is not None:
            update_values["suggestions"] = suggestions
        if is_ready_to_create_feed is not None:
            update_values["is_ready_to_create_feed"] = is_ready_to_create_feed
        if description is not None:
            update_values["description"] = description
        if title is not None:
            update_values["title"] = title
        if tags is not None:
            update_values["tags"] = tags
        if digest_interval_hours is not None:
            update_values["digest_interval_hours"] = digest_interval_hours
        if filters is not None:
            update_values["filters"] = filters
        if filter_ads is not None:
            update_values["filter_ads"] = filter_ads
        if filter_duplicates is not None:
            update_values["filter_duplicates"] = filter_duplicates
        if views_raw is not None:
            update_values["views_raw"] = views_raw
        if filters_raw is not None:
            update_values["filters_raw"] = filters_raw

        if not update_values:
            # Nothing to update, return current data
            select_query = select(pre_prompts).where(pre_prompts.c.id == pre_prompt_id)
            result = await conn.execute(select_query)
            row = result.fetchone()
            if not row:
                raise ValueError(f"Pre-prompt with id {pre_prompt_id} not found")
            return dict(row._mapping)

        update_query = (
            update(pre_prompts)
            .where(pre_prompts.c.id == pre_prompt_id)
            .values(**update_values)
            .returning(pre_prompts)
        )

        result = await conn.execute(update_query)
        row = result.fetchone()

        if not row:
            raise ValueError(f"Failed to update pre_prompt with id {pre_prompt_id}")

        return dict(row._mapping)

    async def get_pre_prompt_for_user(
        self, conn: AsyncConnection, pre_prompt_id: UUID, user_id: UUID
    ) -> dict[str, Any] | None:
        """Get pre_prompt by id with user ownership verification via chats table.

        Args:
            conn: Database connection
            pre_prompt_id: ID of the pre_prompt
            user_id: ID of the user (for ownership check)

        Returns:
            Dictionary containing pre_prompt data or None if not found/not owned
        """
        query = text("""
            SELECT
                pp.id,
                pp.title,
                pp.description,
                pp.created_at,
                pp.type,
                pp.prompt,
                pp.sources,
                pp.digest_interval_hours,
                pp.filter_ads,
                pp.filter_duplicates,
                pp.views_raw,
                pp.filters_raw
            FROM pre_prompts pp
            INNER JOIN chats c ON c.pre_prompt_id = pp.id
            WHERE pp.id = :pre_prompt_id AND c.user_id = :user_id
            LIMIT 1
        """)

        result = await conn.execute(
            query, {"pre_prompt_id": pre_prompt_id, "user_id": user_id}
        )
        row = result.fetchone()

        if not row:
            return None

        return dict(row._mapping)
