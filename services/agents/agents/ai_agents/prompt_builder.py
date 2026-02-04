"""Builder for constructing enhanced filter prompts from user input and system filters."""

from __future__ import annotations

from typing import Any

from .prompts import PREDEFINED_FILTERS


def extract_instruction_and_filters(
    prompt_data: str | dict[str, Any] | None,
) -> tuple[str, list[str]]:
    """Extract instruction and filters from prompt data.

    Handles both legacy (string) and new (dict) formats for backward compatibility.

    Args:
        prompt_data: Prompt data from database. Can be:
            - str: Legacy format, used as instruction directly
            - dict: New format with "instruction" and "filters" keys
            - None: Empty prompt

    Returns:
        Tuple of (instruction, filters)
    """
    if prompt_data is None:
        return "", []

    if isinstance(prompt_data, str):
        # Legacy format: plain string is the instruction
        return prompt_data, []

    if isinstance(prompt_data, dict):
        # New format: dict with instruction and filters
        instruction = prompt_data.get("instruction", "") or ""
        filters = prompt_data.get("filters", []) or []
        return instruction, filters

    # Fallback for unexpected types
    return str(prompt_data), []


def build_filter_prompt(
    user_instruction: str | None,
    filters: list[str] | None,
) -> str:
    """Build enhanced filter prompt from user instruction and system filters.

    Combines user's criteria with predefined system filters into a structured
    XML prompt that the AI will use for filtering decisions.

    The user sees their original instruction, but AI receives an enhanced version
    with additional system filters wrapped in XML tags.

    Args:
        user_instruction: User's filter criteria (shown to user as-is).
            Can be empty string or None.
        filters: List of predefined filter names to apply (e.g., ["remove_ads"]).
            Can be empty list or None.

    Returns:
        Enhanced prompt for AI with XML structure:
        - <user_criteria> for user's instruction (if provided)
        - <system_filters> for predefined filters (if any)
        - Fallback message if both are empty

    Examples:
        >>> build_filter_prompt("про AI", ["remove_ads"])
        '<user_criteria>\\nпро AI\\n</user_criteria>\\n\\n<system_filters>\\n...'

        >>> build_filter_prompt("", ["remove_ads"])
        '<system_filters>\\nОтсеивай рекламный...'

        >>> build_filter_prompt("", [])
        'Пропускай все посты (нет критериев фильтрации)'
    """
    parts: list[str] = []

    # 1. Add user's instruction in XML wrapper
    if user_instruction and user_instruction.strip():
        parts.append(f"<user_criteria>\n{user_instruction.strip()}\n</user_criteria>")

    # 2. Add predefined system filters in XML wrapper
    if filters:
        active_filters: list[str] = []
        for filter_name in filters:
            if filter_name in PREDEFINED_FILTERS:
                active_filters.append(PREDEFINED_FILTERS[filter_name])

        if active_filters:
            filters_text = "\n\n".join(active_filters)
            parts.append(f"<system_filters>\n{filters_text}\n</system_filters>")

    # 3. Fallback if nothing provided - pass all posts
    if not parts:
        return "Пропускай все посты (нет критериев фильтрации)"

    return "\n\n".join(parts)
