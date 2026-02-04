"""LLM cost tracking utilities."""

from decimal import Decimal
from uuid import UUID

from loguru import logger
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import AsyncEngine

from shared.database.tables import user_llm_costs


async def track_llm_cost_async(
    engine: AsyncEngine,
    user_id: UUID | str,
    agent: str,
    model: str,
    prompt_tokens: int,
    completion_tokens: int,
    cost_usd: float,
) -> None:
    """Track LLM cost for a user in database (async).

    Uses provided engine for database connection.

    Args:
        engine: AsyncEngine to use for database connection
        user_id: User ID who made the request
        agent: Name of AI agent class
        model: Model name used
        prompt_tokens: Number of prompt tokens
        completion_tokens: Number of completion tokens
        cost_usd: Cost in USD
    """
    try:
        # Convert user_id to UUID if string
        if isinstance(user_id, str):
            user_id = UUID(user_id)

        total_tokens = prompt_tokens + completion_tokens

        async with engine.begin() as conn:
            query = insert(user_llm_costs).values(
                user_id=user_id,
                agent=agent,
                model=model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=total_tokens,
                cost_usd=Decimal(str(cost_usd)),  # Convert to Decimal for precision
            )

            await conn.execute(query)

        logger.debug(
            f"Tracked LLM cost: user={user_id}, agent={agent}, "
            f"model={model}, tokens={total_tokens}, cost=${cost_usd:.6f}"
        )

    except Exception as e:
        logger.error(f"Failed to track LLM cost: {e}", exc_info=True)
        # Don't raise - tracking failures shouldn't break LLM calls
