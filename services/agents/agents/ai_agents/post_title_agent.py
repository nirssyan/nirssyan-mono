"""LangChain agent for generating post titles."""

from __future__ import annotations

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import POST_TITLE_SYSTEM_PROMPT
from .schemas import PostTitleResponse


class PostTitleAgent(BaseJSONAgent[PostTitleResponse]):
    """Agent for generating post titles using LangChain and AI model.

    Implements smart logic:
    - If post content < 50 characters: uses content as title directly
    - If post content >= 50 characters: generates title using AI
    """

    # Threshold for deciding between direct use vs AI generation
    TITLE_THRESHOLD = 50

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the post title agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        # Use local prompt from prompts.py

        super().__init__(
            response_model=PostTitleResponse,
            system_prompt=POST_TITLE_SYSTEM_PROMPT,
            human_prompt_template="{post_content}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.3,  # Lower temperature for consistent titles,  # Pass for metadata linking
        )

    async def generate_title(
        self, post_content: str, user_id: str | None = None
    ) -> str:
        """Generate a title for post content.

        Smart logic:
        - If content < 50 chars: return content as title (truncated to 40)
        - If content >= 50 chars: use AI to generate title

        Args:
            post_content: The post content to generate title for.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            Generated or extracted title (max 60 characters).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Strip whitespace for accurate length check
        content_stripped = post_content.strip()

        # If content is short, use it as title directly
        if len(content_stripped) < self.TITLE_THRESHOLD:
            # Truncate to 60 characters (Pydantic validation limit)
            title = content_stripped[:60]
            logger.debug(
                f"Using short content as title (length={len(content_stripped)}): {title}"
            )
            return title

        # Content is long enough - use AI to generate title
        logger.debug(
            f"Generating AI title for content (length={len(content_stripped)})"
        )
        result = await self._invoke_chain_async(
            {"post_content": content_stripped}, "generate_title", user_id=user_id
        )
        return result.title

    def generate_title_sync(self, post_content: str, user_id: str | None = None) -> str:
        """Synchronous version of generate_title.

        Args:
            post_content: The post content to generate title for.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            Generated or extracted title (max 60 characters).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Strip whitespace for accurate length check
        content_stripped = post_content.strip()

        # If content is short, use it as title directly
        if len(content_stripped) < self.TITLE_THRESHOLD:
            # Truncate to 60 characters (Pydantic validation limit)
            title = content_stripped[:60]
            logger.debug(
                f"Using short content as title (length={len(content_stripped)}): {title}"
            )
            return title

        # Content is long enough - use AI to generate title
        logger.debug(
            f"Generating AI title for content (length={len(content_stripped)})"
        )
        result = self._invoke_chain_sync(
            {"post_content": content_stripped}, "generate_title_sync", user_id=user_id
        )
        return result.title
