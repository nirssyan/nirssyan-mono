"""AI agent for generating feed tags based on raw posts content."""

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import FEED_TAGS_SYSTEM_PROMPT
from .schemas import FeedTagsResponse


class FeedTagsAgent(BaseJSONAgent[FeedTagsResponse]):
    """Agent for generating feed tags using LangChain and AI model."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the feed tags agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        # Use local prompt from prompts.py

        super().__init__(
            response_model=FeedTagsResponse,
            system_prompt=FEED_TAGS_SYSTEM_PROMPT,
            human_prompt_template=(
                "Данные для анализа:\n"
                "Тексты из raw_posts (последние посты):\n{raw_posts_content}\n\n"
                "Промпт пользователя: {prompt}\n"
                "Тип ленты: {feed_type}\n"
                "Доступные теги: {available_tags}"
            ),
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.1,  # Very low temperature for strict JSON format adherence,  # Pass for metadata linking
        )

    async def generate_tags(
        self,
        raw_posts_content: list[str],
        prompt_text: str | None,
        feed_type: str,
        available_tags: list[str],
        user_id: str | None = None,
    ) -> list[str]:
        """Generate feed tags based on raw posts content and feed metadata.

        Args:
            raw_posts_content: List of text content from raw_posts (last 20 posts).
            prompt_text: The user's prompt text for the feed (can be None for simple subscription).
            feed_type: Type of feed (SINGLE_POST, DIGEST).
            available_tags: List of all available tags (31 tags).
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            List of 1-4 selected tags.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Prepare content summary (join first 20 posts)
        content_summary = (
            "\n---\n".join(raw_posts_content[:20])
            if raw_posts_content
            else "Нет постов"
        )

        # Format available tags as numbered list for better LLM comprehension
        tags_formatted = "\n".join(
            [f"{i + 1}. {tag}" for i, tag in enumerate(available_tags)]
        )

        # Pass variables separately for prompt compatibility
        # Note: If LLM returns >4 tags, Pydantic validator auto-truncates with warning
        result = await self._invoke_chain_async(
            {
                "raw_posts_content": content_summary,
                "prompt": prompt_text or "нет промпта (простая подписка)",
                "feed_type": feed_type,
                "available_tags": tags_formatted,
            },
            "generate_tags",
            user_id=user_id,
        )

        # Log for debugging
        logger.info(
            f"Generated tags for feed (type={feed_type}): {result.tags}. "
            f"Reasoning: {result.reasoning[:100]}..."
        )

        return result.tags

    def generate_tags_sync(
        self,
        raw_posts_content: list[str],
        prompt_text: str | None,
        feed_type: str,
        available_tags: list[str],
        user_id: str | None = None,
    ) -> list[str]:
        """Synchronous version of generate_tags.

        Args:
            raw_posts_content: List of text content from raw_posts (last 20 posts).
            prompt_text: The user's prompt text for the feed (can be None for simple subscription).
            feed_type: Type of feed (SINGLE_POST, DIGEST).
            available_tags: List of all available tags (31 tags).
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            List of 1-4 selected tags.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Prepare content summary (join first 20 posts)
        content_summary = (
            "\n---\n".join(raw_posts_content[:20])
            if raw_posts_content
            else "Нет постов"
        )

        # Format available tags as numbered list for better LLM comprehension
        tags_formatted = "\n".join(
            [f"{i + 1}. {tag}" for i, tag in enumerate(available_tags)]
        )

        # Pass variables separately for prompt compatibility
        result = self._invoke_chain_sync(
            {
                "raw_posts_content": content_summary,
                "prompt": prompt_text or "нет промпта (простая подписка)",
                "feed_type": feed_type,
                "available_tags": tags_formatted,
            },
            "generate_tags_sync",
            user_id=user_id,
        )

        # Log for debugging
        logger.info(
            f"Generated tags for feed (type={feed_type}): {result.tags}. "
            f"Reasoning: {result.reasoning[:100]}..."
        )

        return result.tags
