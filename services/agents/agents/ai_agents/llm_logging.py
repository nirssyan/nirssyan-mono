"""Unified LLM request logging utilities."""

import json
from typing import Any

from loguru import logger

PAYLOAD_PREVIEW_MAX_CHARS = 300


def get_preview(data: Any, max_chars: int = PAYLOAD_PREVIEW_MAX_CHARS) -> str:
    """Create a preview of input/output data for logging.

    Args:
        data: Input data (dict, str, or any JSON-serializable object)
        max_chars: Maximum characters for the preview

    Returns:
        Truncated string representation of the data
    """
    if data is None:
        return "null"

    if isinstance(data, str):
        text = data
    else:
        try:
            text = json.dumps(data, ensure_ascii=False, default=str)
        except (TypeError, ValueError):
            text = str(data)

    text = text.replace("\n", " ").replace("\r", "")

    if len(text) > max_chars:
        return text[:max_chars] + "..."

    return text


def log_llm_request(
    agent: str,
    duration_ms: float,
    cost_usd: float,
    prompt_tokens: int,
    completion_tokens: int,
    input_data: dict[str, Any],
    output: str,
) -> None:
    """Log LLM request in unified format.

    Format:
        LLM | <agent> | <duration>ms | $<cost> | <tokens> | req: <input> | resp: <output>

    Args:
        agent: Name of the AI agent class
        duration_ms: Request duration in milliseconds
        cost_usd: Cost in USD
        prompt_tokens: Number of input tokens
        completion_tokens: Number of output tokens
        input_data: Input data passed to the LLM
        output: Raw output from the LLM
    """
    input_preview = get_preview(input_data)
    output_preview = get_preview(output)

    with logger.contextualize(
        llm_agent=agent,
        llm_duration_ms=round(duration_ms, 1),
        llm_cost_usd=cost_usd,
        llm_prompt_tokens=prompt_tokens,
        llm_completion_tokens=completion_tokens,
    ):
        logger.info(
            f"LLM | {agent} | {duration_ms:.0f}ms | ${cost_usd:.6f} | "
            f"{prompt_tokens}→{completion_tokens} | req: {input_preview} | resp: {output_preview}"
        )
