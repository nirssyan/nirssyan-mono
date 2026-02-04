"""Feed summary agent for creating summaries from multiple RSS posts."""

from __future__ import annotations

from ..config import settings
from .base_agent import BaseJSONAgent
from .prompts import FEED_SUMMARY_SYSTEM_PROMPT
from .schemas import FeedSummaryResponse


class FeedSummaryAgent(BaseJSONAgent[FeedSummaryResponse]):
    """Agent for creating summaries from multiple RSS posts."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        super().__init__(
            response_model=FeedSummaryResponse,
            system_prompt=FEED_SUMMARY_SYSTEM_PROMPT,
            human_prompt_template="Title: {title}\n\nUser prompt: {user_prompt}\n\nPosts to summarize:\n{posts_content}",
            api_key=api_key or settings.feed_summary_api_key or None,
            base_url=base_url or settings.feed_summary_base_url or None,
            model=model or settings.feed_summary_model,
            temperature=0.3,
        )

    async def summarize_posts(
        self,
        user_prompt: str,
        posts_content: list[str],
        title: str = "Summary",
        user_id: str | None = None,
    ) -> FeedSummaryResponse:
        combined_posts = "\n\n---\n\n".join(posts_content)

        return await self._invoke_chain_async(
            {
                "title": title,
                "user_prompt": user_prompt,
                "posts_content": combined_posts,
            },
            "summarize_posts",
            user_id=user_id,
        )

    def summarize_posts_sync(
        self,
        user_prompt: str,
        posts_content: list[str],
        title: str = "Summary",
        user_id: str | None = None,
    ) -> FeedSummaryResponse:
        combined_posts = "\n\n---\n\n".join(posts_content)

        return self._invoke_chain_sync(
            {
                "title": title,
                "user_prompt": user_prompt,
                "posts_content": combined_posts,
            },
            "summarize_posts_sync",
            user_id=user_id,
        )
