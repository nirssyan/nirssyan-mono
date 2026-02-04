"""LangChain agent for transforming user view/filter descriptions into structured configs."""

from __future__ import annotations

from loguru import logger

from ..config import settings
from .base_agent import BaseJSONAgent
from .prompts import (
    VIEW_PROMPT_TRANSFORMER_HUMAN_PROMPT,
    VIEW_PROMPT_TRANSFORMER_SYSTEM_PROMPT,
)
from .schemas import ViewPromptTransformerResponse


class ViewPromptTransformerAgent(BaseJSONAgent[ViewPromptTransformerResponse]):
    """Agent for transforming user-defined views and filters into structured configs.

    Converts human-readable descriptions like "read as if I'm 5" into structured
    {name, prompt} objects for AI processing.
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the view prompt transformer agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. Defaults to settings.view_prompt_transformer_model.
        """
        super().__init__(
            response_model=ViewPromptTransformerResponse,
            system_prompt=VIEW_PROMPT_TRANSFORMER_SYSTEM_PROMPT,
            human_prompt_template=VIEW_PROMPT_TRANSFORMER_HUMAN_PROMPT,
            api_key=api_key,
            base_url=base_url,
            model=model or settings.view_prompt_transformer_model,
            temperature=0.3,
        )

    async def transform(
        self,
        views: list[str],
        filters: list[str],
        context_posts: list[str] | None = None,
        user_id: str | None = None,
    ) -> ViewPromptTransformerResponse:
        """Transform user-defined view and filter descriptions into structured configs.

        Args:
            views: List of human-readable view descriptions.
                   E.g., ["read as if I'm 5", "summarize in 2-3 sentences"]
            filters: List of human-readable filter descriptions.
                     E.g., ["no ads", "only AI-related"]
            context_posts: Sample posts from sources for content type detection.
            user_id: Optional user ID for tracing.

        Returns:
            ViewPromptTransformerResponse with:
                - views: List[ViewConfig] with {name, prompt} for each view
                - filters: List[FilterConfig] with {name, prompt} for each filter

        Raises:
            ValueError: If transformation fails.
        """
        views_str = self._format_list(views)
        filters_str = self._format_list(filters)
        context_str = self._format_context_posts(context_posts)

        logger.debug(
            f"Transforming {len(views)} views and {len(filters)} filters "
            f"with {len(context_posts) if context_posts else 0} context posts"
        )

        result = await self._invoke_chain_async(
            {"views": views_str, "filters": filters_str, "context_posts": context_str},
            "transform",
            user_id=user_id,
        )

        logger.info(
            f"Transformed: {len(result.views)} views, {len(result.filters)} filters"
        )

        return result

    def transform_sync(
        self,
        views: list[str],
        filters: list[str],
        context_posts: list[str] | None = None,
        user_id: str | None = None,
    ) -> ViewPromptTransformerResponse:
        """Synchronous version of transform.

        Args:
            views: List of human-readable view descriptions.
            filters: List of human-readable filter descriptions.
            context_posts: Sample posts from sources for content type detection.
            user_id: Optional user ID for tracing.

        Returns:
            ViewPromptTransformerResponse with structured configs.

        Raises:
            ValueError: If transformation fails.
        """
        views_str = self._format_list(views)
        filters_str = self._format_list(filters)
        context_str = self._format_context_posts(context_posts)

        logger.debug(
            f"Transforming (sync) {len(views)} views and {len(filters)} filters"
        )

        result = self._invoke_chain_sync(
            {"views": views_str, "filters": filters_str, "context_posts": context_str},
            "transform_sync",
            user_id=user_id,
        )

        return result

    def _format_list(self, items: list[str]) -> str:
        """Format a list of items for the prompt.

        Args:
            items: List of strings to format.

        Returns:
            Formatted string with numbered items or "(пусто)" if empty.
        """
        if not items:
            return "(пусто)"

        return "\n".join(f"{i + 1}. {item}" for i, item in enumerate(items))

    def _format_context_posts(self, posts: list[str] | None) -> str:
        """Format context posts for the prompt.

        Args:
            posts: List of sample posts from sources.

        Returns:
            Formatted string with numbered posts (max 5, 500 chars each).
        """
        if not posts:
            return "(нет примеров постов)"

        formatted = []
        for i, post in enumerate(posts[:5], 1):
            truncated = post[:500] + "..." if len(post) > 500 else post
            formatted.append(f"Пост {i}:\n{truncated}")

        return "\n\n".join(formatted)
