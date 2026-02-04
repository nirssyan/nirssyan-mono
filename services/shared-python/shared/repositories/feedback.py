from typing import Any
from uuid import UUID

from sqlalchemy import insert, select
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import feedbacks


class FeedbackRepository:
    """Repository for feedback data access."""

    async def create_feedback(
        self,
        conn: AsyncConnection,
        user_id: UUID,
        message: str | None,
        image_urls: list[str] | None,
    ) -> dict[str, Any]:
        """Create a new feedback.

        Args:
            conn: Database connection
            user_id: User UUID
            message: Feedback message text (optional)
            image_urls: List of image URLs from Supabase Storage (optional)

        Returns:
            Created feedback as dict

        Raises:
            ValueError: If creation fails
        """
        query = (
            insert(feedbacks)
            .values(
                user_id=user_id,
                message=message,
                image_urls=image_urls or [],
            )
            .returning(feedbacks)
        )

        result = await conn.execute(query)
        row = result.fetchone()

        if row is None:
            raise ValueError("Failed to create feedback")

        return dict(row._mapping)

    async def get_feedback_by_id(
        self, conn: AsyncConnection, feedback_id: UUID
    ) -> dict[str, Any] | None:
        """Get feedback by ID.

        Args:
            conn: Database connection
            feedback_id: Feedback UUID

        Returns:
            Feedback data or None if not found
        """
        query = select(feedbacks).where(feedbacks.c.id == feedback_id)
        result = await conn.execute(query)
        row = result.fetchone()

        return dict(row._mapping) if row else None
