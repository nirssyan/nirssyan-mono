"""Utilities for parsing prompt data from database."""

from __future__ import annotations

from typing import Any


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
        return prompt_data, []

    if isinstance(prompt_data, dict):
        instruction = prompt_data.get("instruction", "") or ""
        filters = prompt_data.get("filters", []) or []
        return instruction, filters

    return str(prompt_data), []
