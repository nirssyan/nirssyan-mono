"""Repository for prompt examples operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection


class PromptExampleRepository:
    """Repository for managing prompt examples in the database."""

    async def get_prompt_examples_by_user_tags(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        """Get all prompt examples matching user's tags.

        Args:
            conn: Database connection
            user_id: User UUID

        Returns:
            List of prompt examples with their tags
        """
        query = text("""
            SELECT DISTINCT
                pe.id,
                pe.prompt,
                pe.created_at,
                COALESCE(array_agg(DISTINCT t.name) FILTER (WHERE t.name IS NOT NULL), '{}') as tags
            FROM prompt_examples pe
            JOIN prompt_examples_tags pet ON pet.prompt_example_id = pe.id
            JOIN tags t ON t.id = pet.tag_id
            WHERE pet.tag_id IN (
                SELECT tag_id FROM users_tags WHERE user_id = :user_id
            )
            GROUP BY pe.id, pe.prompt, pe.created_at
            ORDER BY pe.created_at DESC
        """)

        result = await conn.execute(query, {"user_id": user_id})
        return [dict(row._mapping) for row in result.fetchall()]
