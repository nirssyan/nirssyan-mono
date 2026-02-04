"""LangChain agent for generating comments on feed posts based on user criteria."""

from __future__ import annotations

from .base_agent import BaseJSONAgent
from .prompts import FEED_COMMENT_SYSTEM_PROMPT
from .schemas import FeedCommentResponse


class FeedCommentAgent(BaseJSONAgent[FeedCommentResponse]):
    """Agent for generating comments on feed posts using LangChain and AI model."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the feed comment agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        # Use local prompt from prompts.py

        super().__init__(
            response_model=FeedCommentResponse,
            system_prompt=FEED_COMMENT_SYSTEM_PROMPT,
            human_prompt_template="User prompt: {comment_prompt}\nPost content: {post_content}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.7,  # Higher temperature for more creative comments,  # Pass for metadata linking
        )

    async def generate_comment(
        self, comment_prompt: str, post_content: str, user_id: str | None = None
    ) -> FeedCommentResponse:
        """Generate a comment for a post based on user criteria.

        Args:
            comment_prompt: The commenting style and criteria from user.
            post_content: The post content to comment on.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            FeedCommentResponse with comment and title (max 60 characters).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        return await self._invoke_chain_async(
            {"comment_prompt": comment_prompt, "post_content": post_content},
            "generate_comment",
            user_id=user_id,
        )

    def generate_comment_sync(
        self, comment_prompt: str, post_content: str, user_id: str | None = None
    ) -> FeedCommentResponse:
        """Synchronous version of generate_comment.

        Args:
            comment_prompt: The commenting style and criteria from user.
            post_content: The post content to comment on.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            FeedCommentResponse with comment and title.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        return self._invoke_chain_sync(
            {"comment_prompt": comment_prompt, "post_content": post_content},
            "generate_comment_sync",
            user_id=user_id,
        )
