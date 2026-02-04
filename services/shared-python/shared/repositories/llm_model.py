"""Repository for LLM models operations."""

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import insert, select, update
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import llm_model_price_history, llm_models


class LlmModelsRepository:
    """Repository for managing LLM models in the database."""

    async def get_all_model_ids(self, conn: AsyncConnection) -> set[str]:
        """Get all existing model_ids for comparison.

        Args:
            conn: Database connection

        Returns:
            Set of model_id strings
        """
        query = select(llm_models.c.model_id)
        result = await conn.execute(query)
        return {row.model_id for row in result.fetchall()}

    async def get_model_by_id(
        self, conn: AsyncConnection, model_id: str
    ) -> dict[str, Any] | None:
        """Get model with current prices.

        Args:
            conn: Database connection
            model_id: OpenRouter model ID

        Returns:
            Model dict or None if not found
        """
        query = select(llm_models).where(llm_models.c.model_id == model_id)
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            return None
        return dict(row._mapping)

    async def get_all_active_models(
        self, conn: AsyncConnection
    ) -> list[dict[str, Any]]:
        """Get all active models with prices.

        Args:
            conn: Database connection

        Returns:
            List of model dicts
        """
        query = select(llm_models).where(llm_models.c.is_active == True)  # noqa: E712
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def insert_model(
        self, conn: AsyncConnection, model_data: dict[str, Any]
    ) -> UUID:
        """Insert a new model.

        Args:
            conn: Database connection
            model_data: Model data dict

        Returns:
            UUID of created model
        """
        query = insert(llm_models).values(**model_data).returning(llm_models.c.id)
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to insert model")
        return row.id

    async def update_model(
        self,
        conn: AsyncConnection,
        model_id: str,
        update_data: dict[str, Any],
    ) -> None:
        """Update an existing model.

        Args:
            conn: Database connection
            model_id: OpenRouter model ID
            update_data: Fields to update
        """
        update_data["updated_at"] = datetime.now(timezone.utc)
        query = (
            update(llm_models)
            .where(llm_models.c.model_id == model_id)
            .values(**update_data)
        )
        await conn.execute(query)

    async def record_price_change(
        self,
        conn: AsyncConnection,
        llm_model_uuid: UUID,
        model_id: str,
        prev_price_prompt: Decimal,
        prev_price_completion: Decimal,
        new_price_prompt: Decimal,
        new_price_completion: Decimal,
    ) -> UUID:
        """Record a price change in history.

        Args:
            conn: Database connection
            llm_model_uuid: UUID of the llm_models record
            model_id: OpenRouter model ID
            prev_price_prompt: Previous prompt price
            prev_price_completion: Previous completion price
            new_price_prompt: New prompt price
            new_price_completion: New completion price

        Returns:
            UUID of created price history record
        """
        change_percent_prompt = None
        change_percent_completion = None

        if prev_price_prompt and prev_price_prompt != 0:
            change_percent_prompt = (
                (new_price_prompt - prev_price_prompt) / prev_price_prompt * 100
            )

        if prev_price_completion and prev_price_completion != 0:
            change_percent_completion = (
                (new_price_completion - prev_price_completion)
                / prev_price_completion
                * 100
            )

        query = (
            insert(llm_model_price_history)
            .values(
                llm_model_uuid=llm_model_uuid,
                model_id=model_id,
                prev_price_prompt=prev_price_prompt,
                prev_price_completion=prev_price_completion,
                new_price_prompt=new_price_prompt,
                new_price_completion=new_price_completion,
                change_percent_prompt=change_percent_prompt,
                change_percent_completion=change_percent_completion,
            )
            .returning(llm_model_price_history.c.id)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to record price change")
        return row.id

    async def get_models_added_since(
        self, conn: AsyncConnection, since: datetime
    ) -> list[dict[str, Any]]:
        """Get models added after timestamp.

        Args:
            conn: Database connection
            since: Datetime threshold

        Returns:
            List of model dicts
        """
        query = select(llm_models).where(llm_models.c.created_at > since)
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_price_changes_since(
        self, conn: AsyncConnection, since: datetime
    ) -> list[dict[str, Any]]:
        """Get price changes after timestamp.

        Args:
            conn: Database connection
            since: Datetime threshold

        Returns:
            List of price history dicts
        """
        query = select(llm_model_price_history).where(
            llm_model_price_history.c.created_at > since
        )
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def get_all_prices_for_cache(
        self, conn: AsyncConnection
    ) -> dict[str, dict[str, float]]:
        """Get all model prices for caching.

        Args:
            conn: Database connection

        Returns:
            Dict mapping model_id to pricing dict
        """
        query = select(
            llm_models.c.model_id,
            llm_models.c.price_prompt,
            llm_models.c.price_completion,
        ).where(llm_models.c.is_active == True)  # noqa: E712
        result = await conn.execute(query)
        return {
            row.model_id: {
                "prompt": float(row.price_prompt) * 1_000_000,
                "completion": float(row.price_completion) * 1_000_000,
            }
            for row in result.fetchall()
        }
