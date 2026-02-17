"""LangChain agent for generating dynamic post views."""

from __future__ import annotations

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import (
    TLDR_VIEW_PROMPT,
    VIEW_GENERATOR_HUMAN_PROMPT,
    VIEW_GENERATOR_SYSTEM_PROMPT,
    is_summary_like_prompt,
)
from .schemas import ViewGeneratorResponse


class ViewGeneratorAgent(BaseJSONAgent[ViewGeneratorResponse]):
    """Agent for generating dynamic post views using LangChain and AI model.

    Transforms post content according to a view-specific prompt (e.g.,
    "explain like I'm 5", "summarize in 3 sentences", etc.).
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the view generator agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        super().__init__(
            response_model=ViewGeneratorResponse,
            system_prompt=VIEW_GENERATOR_SYSTEM_PROMPT,
            human_prompt_template=VIEW_GENERATOR_HUMAN_PROMPT,
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.5,
        )

    async def generate_view(
        self,
        content: str,
        view_prompt: str,
        user_id: str | None = None,
    ) -> str:
        """Generate a view transformation of content.

        Args:
            content: Original post content to transform.
            view_prompt: Instruction for how to transform the content.
            user_id: Optional user ID for tracing.

        Returns:
            Transformed content string. Falls back to original content if LLM fails.

        Raises:
            ValueError: If validation fails or generation errors occur (after fallback).
        """
        if is_summary_like_prompt(view_prompt):
            view_prompt = TLDR_VIEW_PROMPT

        logger.debug(
            f"Generating view with prompt: '{view_prompt[:50]}...' "
            f"for content length={len(content)}"
        )

        try:
            result = await self._invoke_chain_async(
                {"content": content, "view_prompt": view_prompt},
                "generate_view",
                user_id=user_id,
            )

            logger.debug(f"Generated view: {len(result.content)} chars")
            return result.content
        except ValueError as e:
            error_msg = str(e)
            # Check if error is related to JSON parsing or empty response
            if (
                "Could not find valid JSON" in error_msg
                or "empty response" in error_msg.lower()
                or "LLM returned empty" in error_msg
            ):
                logger.warning(
                    f"LLM failed to generate view after retries, "
                    f"falling back to original content. Error: {error_msg}"
                )
                return content
            # Re-raise other ValueError exceptions (e.g., validation errors)
            raise
