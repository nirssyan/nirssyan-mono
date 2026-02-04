"""LangChain agent for generating feed titles."""

from __future__ import annotations

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import FEED_TITLE_SYSTEM_PROMPT
from .schemas import FeedTitleResponse


class FeedTitleAgent(BaseJSONAgent[FeedTitleResponse]):
    """Agent for generating feed titles using LangChain and AI model.

    Generates a 1-2 word title based on feed configuration and sample posts.
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the feed title agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        super().__init__(
            response_model=FeedTitleResponse,
            system_prompt=FEED_TITLE_SYSTEM_PROMPT,
            human_prompt_template="{context}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.5,
        )

    async def generate_feed_title(
        self,
        feed_filters: dict,
        sample_posts: list[str],
        user_id: str | None = None,
    ) -> str:
        """Generate a 1-2 word title for a feed.

        Args:
            feed_filters: Feed configuration dict with keys:
                - prompt: Filter/processing prompt
                - type: Feed type (SINGLE_POST, DIGEST)
                - filter_ads: Whether ads are filtered
                - filter_duplicates: Whether duplicates are filtered
                - sources: List of source channel names
                - digest_interval_hours: Hours between digests (if applicable)
            sample_posts: List of sample post contents from sources (max 10).
            user_id: Optional user ID for tracing.

        Returns:
            Generated title (1-2 words, max 30 characters).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        context = self._build_context(feed_filters, sample_posts)

        logger.debug(f"Generating feed title with context length={len(context)}")

        result = await self._invoke_chain_async(
            {"context": context}, "generate_feed_title", user_id=user_id
        )
        return result.title

    def generate_feed_title_sync(
        self,
        feed_filters: dict,
        sample_posts: list[str],
        user_id: str | None = None,
    ) -> str:
        """Synchronous version of generate_feed_title.

        Args:
            feed_filters: Feed configuration dict.
            sample_posts: List of sample post contents from sources.
            user_id: Optional user ID for tracing.

        Returns:
            Generated title (1-2 words, max 30 characters).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        context = self._build_context(feed_filters, sample_posts)

        logger.debug(f"Generating feed title (sync) with context length={len(context)}")

        result = self._invoke_chain_sync(
            {"context": context}, "generate_feed_title_sync", user_id=user_id
        )
        return result.title

    def _build_context(self, feed_filters: dict, sample_posts: list[str]) -> str:
        """Build context string from feed filters and sample posts.

        Args:
            feed_filters: Feed configuration dict.
            sample_posts: List of sample post contents.

        Returns:
            Formatted context string for the AI model.
        """
        sources = feed_filters.get("sources") or []
        sources_str = ", ".join(sources) if sources else "не указаны"

        feed_type = feed_filters.get("type") or "не указан"
        prompt = feed_filters.get("prompt") or "не указан"
        filter_ads = "да" if feed_filters.get("filter_ads") else "нет"
        filter_duplicates = "да" if feed_filters.get("filter_duplicates") else "нет"
        digest_interval = feed_filters.get("digest_interval_hours")
        views_raw = feed_filters.get("views_raw") or []
        filters_raw = feed_filters.get("filters_raw") or []

        context_parts = [
            "=== КОНФИГУРАЦИЯ ЛЕНТЫ ===",
            f"Тип: {feed_type}",
            f"Промпт/фильтр: {prompt}",
            f"Источники: {sources_str}",
            f"Фильтровать рекламу: {filter_ads}",
            f"Фильтровать дубликаты: {filter_duplicates}",
        ]

        if digest_interval:
            context_parts.append(f"Интервал дайджеста: {digest_interval} часов")

        if views_raw:
            context_parts.append(f"Представления: {', '.join(views_raw)}")

        if filters_raw:
            context_parts.append(f"Фильтры: {', '.join(filters_raw)}")

        context_parts.append("")
        context_parts.append("=== ПРИМЕРЫ ПОСТОВ ИЗ ИСТОЧНИКОВ ===")

        if sample_posts:
            for i, post in enumerate(sample_posts[:10], 1):
                truncated = post[:300] if len(post) > 300 else post
                context_parts.append(f"\n--- Пост {i} ---")
                context_parts.append(truncated)
        else:
            context_parts.append("(примеры постов недоступны)")

        return "\n".join(context_parts)
