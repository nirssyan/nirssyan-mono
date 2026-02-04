"""LLM pricing calculator for different models.

Loads pricing from database (synced from OpenRouter API).
Falls back to conservative default pricing if model not found.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import llm_models

# In-memory cache for pricing loaded from database
_pricing_cache: dict[str, dict[str, float]] = {}

# Default pricing if model not found in database (conservative estimate)
# Used when: 1) cache not loaded, 2) model not in database
DEFAULT_PRICING = {
    "prompt": 1.00,  # $1.00 per 1M tokens
    "completion": 3.00,  # $3.00 per 1M tokens
}


async def load_pricing_from_db(conn: AsyncConnection) -> None:
    """Load all model pricing from database into cache.

    Prices in database are stored per token, but we convert to per 1M tokens
    for cost calculation.

    Args:
        conn: Database connection
    """
    global _pricing_cache
    query = select(
        llm_models.c.model_id,
        llm_models.c.price_prompt,
        llm_models.c.price_completion,
    ).where(llm_models.c.is_active == True)  # noqa: E712

    result = await conn.execute(query)
    _pricing_cache = {
        row.model_id: {
            "prompt": float(row.price_prompt) * 1_000_000,
            "completion": float(row.price_completion) * 1_000_000,
        }
        for row in result.fetchall()
    }


def get_pricing_cache_size() -> int:
    """Get the number of models in the pricing cache.

    Returns:
        Number of cached models
    """
    return len(_pricing_cache)


def get_model_pricing(model: str) -> dict[str, float]:
    """Get pricing information for a model.

    Priority:
    1. Database cache (if loaded via load_pricing_from_db)
    2. DEFAULT_PRICING (conservative fallback)

    Args:
        model: Model name (e.g., "mistralai/mistral-nemo")

    Returns:
        Dict with "prompt" and "completion" pricing per 1M tokens
    """
    if model in _pricing_cache:
        return _pricing_cache[model].copy()

    return DEFAULT_PRICING.copy()


def calculate_cost(model: str, prompt_tokens: int, completion_tokens: int) -> float:
    """Calculate LLM cost in USD.

    Uses pricing from database cache. Falls back to DEFAULT_PRICING
    if model not found (this may overestimate cost).

    Args:
        model: Model name (e.g., "mistralai/mistral-nemo")
        prompt_tokens: Number of prompt tokens
        completion_tokens: Number of completion tokens

    Returns:
        Total cost in USD (6 decimal places precision)
    """
    pricing = get_model_pricing(model)

    # Calculate cost per 1M tokens
    prompt_cost = (prompt_tokens / 1_000_000) * pricing["prompt"]
    completion_cost = (completion_tokens / 1_000_000) * pricing["completion"]

    total_cost = prompt_cost + completion_cost

    # Round to 6 decimal places (microdollars)
    return round(total_cost, 6)
