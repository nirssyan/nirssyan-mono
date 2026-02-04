"""LangChain agent for generating feed descriptions."""

from __future__ import annotations

from .base_agent import BaseJSONAgent
from .prompts import FEED_DESCRIPTION_SYSTEM_PROMPT
from .schemas import FeedDescriptionResponse


class FeedDescriptionAgent(BaseJSONAgent[FeedDescriptionResponse]):
    """Agent for generating feed descriptions using LangChain and AI model."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the feed description agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        # Use local prompt from prompts.py

        super().__init__(
            response_model=FeedDescriptionResponse,
            system_prompt=FEED_DESCRIPTION_SYSTEM_PROMPT,
            human_prompt_template="Информация о ленте:\nPrompt: {prompt}\nSources: {sources}\nType: {type}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.7,  # Pass for metadata linking
        )

    async def generate_description(
        self,
        prompt: str | None,
        sources: list[str] | None,
        feed_type: str | None,
        user_id: str | None = None,
    ) -> str:
        """Generate a feed description from current feed info.

        Args:
            prompt: The user's prompt text (can be None for simple subscription).
            sources: List of Telegram channel usernames.
            feed_type: Type of feed (SINGLE_POST, DIGEST).
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            Generated feed description.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Pass variables separately for prompt compatibility
        sources_str = ", ".join(sources) if sources else "нет источников"

        result = await self._invoke_chain_async(
            {
                "prompt": prompt or "нет промпта",
                "sources": sources_str,
                "type": feed_type or "не указан",
            },
            "generate_description",
            user_id=user_id,
        )
        return result.description

    def generate_description_sync(
        self,
        prompt: str | None,
        sources: list[str] | None,
        feed_type: str | None,
        user_id: str | None = None,
    ) -> str:
        """Synchronous version of generate_description.

        Args:
            prompt: The user's prompt text (can be None for simple subscription).
            sources: List of Telegram channel usernames.
            feed_type: Type of feed (SINGLE_POST, DIGEST).
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            Generated feed description.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Pass variables separately for prompt compatibility
        sources_str = ", ".join(sources) if sources else "нет источников"

        result = self._invoke_chain_sync(
            {
                "prompt": prompt or "нет промпта",
                "sources": sources_str,
                "type": feed_type or "не указан",
            },
            "generate_description_sync",
            user_id=user_id,
        )
        return result.description
