"""LangChain agent for filtering feed posts based on user criteria."""

from __future__ import annotations

import re

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import FEED_FILTER_SYSTEM_PROMPT
from .schemas import FeedFilterResponse

SIMPLE_FILTER_PATTERNS = [
    r"^(?:этот )?пост про (.+?)\??$",
    r"^(?:пост )?о (.+?)\??$",
    r"^(.+?)\??$",
]


def _extract_keyword_from_simple_filter(filter_prompt: str) -> str | None:
    """Extract keyword from simple filter like 'Этот пост про X?' or 'X?'.

    Returns keyword if filter is simple, None if complex filter requiring full LLM analysis.
    """
    normalized = filter_prompt.strip().lower()

    for pattern in SIMPLE_FILTER_PATTERNS:
        match = re.match(pattern, normalized, re.IGNORECASE)
        if match:
            keyword = match.group(1).strip()
            if keyword and len(keyword) >= 2 and " " not in keyword:
                return keyword
    return None


def _keyword_literally_present(keyword: str, text: str) -> bool:
    """Check if keyword is literally present in text (case-insensitive, word boundary)."""
    pattern = rf"\b{re.escape(keyword)}\b"
    return bool(re.search(pattern, text, re.IGNORECASE))


class FeedFilterAgent(BaseJSONAgent[FeedFilterResponse]):
    """Agent for filtering feed posts using LangChain and AI model."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the feed filter agent.

        Args:
            api_key: AI API key. If None, will use config settings.
            base_url: AI base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults to configured ai_model.
        """
        super().__init__(
            response_model=FeedFilterResponse,
            system_prompt=FEED_FILTER_SYSTEM_PROMPT,
            human_prompt_template="Filter prompt: {filter_prompt}\nPost content: {post_content}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.1,  # Lower temperature for more consistent filtering
        )

    async def evaluate_post(
        self, filter_prompt: str, post_content: str, user_id: str | None = None
    ) -> FeedFilterResponse:
        """Evaluate if a post passes the filter criteria.

        Uses pre-check for simple keyword filters to avoid LLM hallucinations.
        If keyword is literally present in text, returns True immediately.

        Args:
            filter_prompt: The filter criteria to evaluate against.
            post_content: The post content to evaluate.
            user_id: Optional user ID for tracing.

        Returns:
            FeedFilterResponse with result, title (max 60 characters), and explanation.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        keyword = _extract_keyword_from_simple_filter(filter_prompt)
        if keyword and _keyword_literally_present(keyword, post_content):
            logger.info(
                f"✅ Pre-check PASS: keyword '{keyword}' found in post, skipping LLM"
            )
            title = (
                post_content[:57] + "..." if len(post_content) > 60 else post_content
            )
            title = title.split("\n")[0][:60]
            return FeedFilterResponse(
                result=True,
                title=title,
                explanation=f"Слово '{keyword}' найдено в тексте поста (pre-check)",
            )

        return await self._invoke_chain_async(
            {"filter_prompt": filter_prompt, "post_content": post_content},
            "evaluate_post",
            user_id=user_id,
        )

    def evaluate_post_sync(
        self, filter_prompt: str, post_content: str, user_id: str | None = None
    ) -> FeedFilterResponse:
        """Synchronous version of evaluate_post.

        Uses pre-check for simple keyword filters to avoid LLM hallucinations.

        Args:
            filter_prompt: The filter criteria to evaluate against.
            post_content: The post content to evaluate.
            user_id: Optional user ID for tracing.

        Returns:
            FeedFilterResponse with result, title, and explanation.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        keyword = _extract_keyword_from_simple_filter(filter_prompt)
        if keyword and _keyword_literally_present(keyword, post_content):
            logger.info(
                f"✅ Pre-check PASS: keyword '{keyword}' found in post, skipping LLM"
            )
            title = (
                post_content[:57] + "..." if len(post_content) > 60 else post_content
            )
            title = title.split("\n")[0][:60]
            return FeedFilterResponse(
                result=True,
                title=title,
                explanation=f"Слово '{keyword}' найдено в тексте поста (pre-check)",
            )

        return self._invoke_chain_sync(
            {"filter_prompt": filter_prompt, "post_content": post_content},
            "evaluate_post_sync",
            user_id=user_id,
        )
