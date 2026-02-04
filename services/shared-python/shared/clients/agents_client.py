"""Async client for calling AI agents via NATS RPC."""

import asyncio
from typing import Any, TypeVar

from faststream.nats import NatsBroker
from loguru import logger

from shared.context import get_request_id
from shared.events.agent_requests import (
    AGENT_SUBJECTS,
    BuildFilterPromptRequest,
    BuildFilterPromptResponse,
    BulletSummaryRequest,
    BulletSummaryResponse,
    ChatMessageRequest,
    ChatMessageResponse,
    FeedDescriptionRequest,
    FeedDescriptionResponse,
    FeedFilterRequest,
    FeedFilterResponse,
    FeedSummaryRequest,
    FeedSummaryResponse,
    FeedTagsRequest,
    FeedTagsResponse,
    FeedTitleRequest,
    FeedTitleResponse,
    PostTitleRequest,
    PostTitleResponse,
    UnseenSummaryRequest,
    UnseenSummaryResponse,
    ViewGeneratorRequest,
    ViewGeneratorResponse,
    ViewPromptTransformerRequest,
    ViewPromptTransformerResponse,
)


class AgentsClientError(Exception):
    """Error from agents RPC call."""

    pass


T = TypeVar("T")


class AgentsClient:
    """Async client for AI agents via NATS RPC.

    All methods are async and non-blocking.
    Includes automatic retry with exponential backoff for timeout errors.
    """

    def __init__(
        self,
        broker: NatsBroker,
        timeout: float = 30.0,
        max_retries: int = 3,
        retry_base_delay: float = 1.0,
    ) -> None:
        """Initialize agents client.

        Args:
            broker: FastStream NATS broker instance
            timeout: Default timeout for RPC calls in seconds
            max_retries: Maximum number of retry attempts on timeout
            retry_base_delay: Base delay for exponential backoff in seconds
        """
        self._broker = broker
        self._timeout = timeout
        self._max_retries = max_retries
        self._retry_base_delay = retry_base_delay

    async def _request(
        self,
        subject: str,
        request: Any,
        response_type: type,
        timeout: float | None = None,
    ) -> Any:
        """Make async RPC request to agent (single attempt).

        Args:
            subject: NATS subject for the agent
            request: Request Pydantic model
            response_type: Expected response type
            timeout: Optional custom timeout

        Returns:
            Parsed response

        Raises:
            AgentsClientError: If agent returns error or request fails
        """
        timeout = timeout or self._timeout

        headers: dict[str, str] = {}
        request_id = get_request_id()
        if request_id:
            headers["X-Request-ID"] = request_id

        try:
            response = await self._broker.request(
                message=request.model_dump(mode="json"),
                subject=subject,
                timeout=timeout,
                headers=headers if headers else None,
            )

            data = await response.decode()

            # Check for error response
            if (
                isinstance(data, dict)
                and "error" in data
                and not data.get("success", True)
            ):
                raise AgentsClientError(data["error"])

            return response_type.model_validate(data)

        except TimeoutError as e:
            logger.error(f"RPC timeout calling {subject}: {e}")
            raise AgentsClientError(f"Agent timeout: {subject}") from e
        except Exception as e:
            if isinstance(e, AgentsClientError):
                raise
            logger.error(f"RPC error calling {subject}: {e}")
            raise AgentsClientError(f"Agent error: {e}") from e

    async def _request_with_retry(
        self,
        subject: str,
        request: Any,
        response_type: type[T],
        timeout: float | None = None,
    ) -> T:
        """Make RPC request with retry on timeout.

        Uses exponential backoff between retries.

        Args:
            subject: NATS subject for the agent
            request: Request Pydantic model
            response_type: Expected response type
            timeout: Optional custom timeout

        Returns:
            Parsed response

        Raises:
            AgentsClientError: If all retries fail
        """
        last_error: Exception | None = None

        for attempt in range(self._max_retries):
            try:
                return await self._request(subject, request, response_type, timeout)

            except AgentsClientError as e:
                last_error = e
                error_str = str(e).lower()

                # Retry only on timeout, not on validation or other errors
                if "timeout" not in error_str:
                    raise

                if attempt < self._max_retries - 1:
                    delay = self._retry_base_delay * (2**attempt)
                    logger.warning(
                        f"RPC timeout for {subject}, retrying in {delay:.1f}s "
                        f"(attempt {attempt + 1}/{self._max_retries})"
                    )
                    await asyncio.sleep(delay)
                    continue

        # All retries exhausted
        logger.error(f"All {self._max_retries} retries failed for {subject}")
        raise last_error or AgentsClientError(f"All retries failed: {subject}")

    async def evaluate_post(
        self,
        filter_prompt: str,
        post_content: str,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> FeedFilterResponse:
        """Evaluate post against filter prompt.

        Uses retry with backoff on timeout.

        Args:
            filter_prompt: Filter criteria
            post_content: Post content to evaluate
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            FeedFilterResponse with result, title, explanation
        """
        request = FeedFilterRequest(
            filter_prompt=filter_prompt,
            post_content=post_content,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["feed_filter"],
            request,
            FeedFilterResponse,
            timeout,
        )

    async def generate_tags(
        self,
        raw_posts_content: list[str],
        feed_type: str,
        available_tags: list[str],
        prompt_text: str | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> FeedTagsResponse:
        """Generate tags for posts.

        Uses retry with backoff on timeout.

        Args:
            raw_posts_content: List of post contents
            feed_type: Type of feed
            available_tags: List of available tags
            prompt_text: Optional prompt text
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            FeedTagsResponse with tags list
        """
        request = FeedTagsRequest(
            raw_posts_content=raw_posts_content,
            prompt_text=prompt_text,
            feed_type=feed_type,
            available_tags=available_tags,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["feed_tags"],
            request,
            FeedTagsResponse,
            timeout,
        )

    async def summarize_posts(
        self,
        user_prompt: str,
        posts_content: list[str],
        title: str = "Summary",
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> FeedSummaryResponse:
        """Summarize posts content.

        Uses retry with backoff on timeout.

        Args:
            user_prompt: User's summarization prompt
            posts_content: List of post contents
            title: Optional summary title
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout (default: 90s for summarization)

        Returns:
            FeedSummaryResponse with title and summary
        """
        request = FeedSummaryRequest(
            user_prompt=user_prompt,
            posts_content=posts_content,
            title=title,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["feed_summary"],
            request,
            FeedSummaryResponse,
            timeout or 90.0,  # Increased timeout for multi-post summarization
        )

    async def generate_feed_title(
        self,
        feed_filters: dict[str, Any],
        sample_posts: list[str],
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> FeedTitleResponse:
        """Generate title for feed.

        Uses retry with backoff on timeout.

        Args:
            feed_filters: Feed filter configuration
            sample_posts: Sample posts for context
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            FeedTitleResponse with title
        """
        request = FeedTitleRequest(
            feed_filters=feed_filters,
            sample_posts=sample_posts,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["feed_title"],
            request,
            FeedTitleResponse,
            timeout,
        )

    async def generate_description(
        self,
        prompt: str | None = None,
        sources: list[str] | None = None,
        feed_type: str | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> FeedDescriptionResponse:
        """Generate feed description.

        Uses retry with backoff on timeout.

        Args:
            prompt: Optional prompt for description
            sources: Optional list of sources
            feed_type: Optional feed type
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            FeedDescriptionResponse with description
        """
        request = FeedDescriptionRequest(
            prompt=prompt,
            sources=sources,
            feed_type=feed_type,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["feed_description"],
            request,
            FeedDescriptionResponse,
            timeout,
        )

    async def process_chat_message(
        self,
        user_message: str,
        current_state: dict[str, Any] | None = None,
        chat_history: list[dict[str, Any]] | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> ChatMessageResponse:
        """Process chat message for feed creation.

        Uses retry with backoff on timeout.

        Args:
            user_message: User's message
            current_state: Current chat state
            chat_history: Previous chat messages
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout (default: 60s for chat)

        Returns:
            ChatMessageResponse with response, current_feed_info, etc.
        """
        request = ChatMessageRequest(
            user_message=user_message,
            current_state=current_state,
            chat_history=chat_history,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["chat_message"],
            request,
            ChatMessageResponse,
            timeout or 60.0,  # Chat messages may need more time
        )

    async def summarize_unseen(
        self,
        posts_data: list[dict[str, Any]],
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> UnseenSummaryResponse:
        """Summarize unseen posts.

        Uses retry with backoff on timeout.

        Args:
            posts_data: List of post data dictionaries
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout (default: 90s for summarization)

        Returns:
            UnseenSummaryResponse with title, summary, full_text
        """
        request = UnseenSummaryRequest(
            posts_data=posts_data,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["unseen_summary"],
            request,
            UnseenSummaryResponse,
            timeout or 90.0,  # Increased timeout for multi-post summarization
        )

    async def generate_view(
        self,
        content: str,
        view_prompt: str,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> ViewGeneratorResponse:
        """Generate view for content.

        Uses retry with backoff on timeout.

        Args:
            content: Content to transform
            view_prompt: View transformation prompt
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            ViewGeneratorResponse with transformed content
        """
        request = ViewGeneratorRequest(
            content=content,
            view_prompt=view_prompt,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["view_generator"],
            request,
            ViewGeneratorResponse,
            timeout,
        )

    async def generate_post_title(
        self,
        post_content: str,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> PostTitleResponse:
        """Generate title for post.

        Uses retry with backoff on timeout.

        Args:
            post_content: Post content
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout (default: 45s for LLM operations)

        Returns:
            PostTitleResponse with title
        """
        request = PostTitleRequest(
            post_content=post_content,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["post_title"],
            request,
            PostTitleResponse,
            timeout or 45.0,  # Increased timeout for LLM
        )

    async def transform_views(
        self,
        views: list[str],
        filters: list[str],
        context_posts: list[str] | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> ViewPromptTransformerResponse:
        """Transform user view/filter descriptions into structured configs.

        Uses retry with backoff on timeout.

        Args:
            views: List of human-readable view descriptions
            filters: List of human-readable filter descriptions
            context_posts: Sample posts from sources for content type detection
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            ViewPromptTransformerResponse with views and filters configs
        """
        request = ViewPromptTransformerRequest(
            views=views,
            filters=filters,
            context_posts=context_posts,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["view_prompt_transformer"],
            request,
            ViewPromptTransformerResponse,
            timeout,
        )

    async def transform_views_to_config(
        self,
        views_raw: list[str],
        context_posts: list[str] | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> list[dict]:
        """Transform user view descriptions into structured configs.

        Args:
            views_raw: List of human-readable view descriptions
            context_posts: Sample posts from sources for content type detection
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            List of view config dicts [{name: {ru, en}, prompt}]
        """
        response = await self.transform_views(
            views=views_raw,
            filters=[],
            context_posts=context_posts,
            user_id=user_id,
            timeout=timeout,
        )
        return [v.model_dump() for v in response.views]

    async def transform_filters_to_config(
        self,
        filters_raw: list[str],
        context_posts: list[str] | None = None,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> list[dict]:
        """Transform user filter descriptions into structured configs.

        Args:
            filters_raw: List of human-readable filter descriptions
            context_posts: Sample posts from sources for content type detection
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            List of filter config dicts [{name: {ru, en}, prompt}]
        """
        response = await self.transform_views(
            views=[],
            filters=filters_raw,
            context_posts=context_posts,
            user_id=user_id,
            timeout=timeout,
        )
        return [f.model_dump() for f in response.filters]

    async def generate_bullet_summary(
        self,
        content: str,
        user_id: str | None = None,
        timeout: float | None = None,
    ) -> BulletSummaryResponse:
        """Generate bullet point summary for content.

        Uses retry with backoff on timeout.

        Args:
            content: Content to summarize
            user_id: Optional user ID for tracing
            timeout: Optional custom timeout

        Returns:
            BulletSummaryResponse with summarized content
        """
        request = BulletSummaryRequest(
            content=content,
            user_id=user_id,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["bullet_summary"],
            request,
            BulletSummaryResponse,
            timeout,
        )

    async def build_filter_prompt(
        self,
        user_instruction: str | None = None,
        filters: list[str] | None = None,
        timeout: float | None = None,
    ) -> BuildFilterPromptResponse:
        """Build enhanced filter prompt from user instruction and filters.

        Uses retry with backoff on timeout.

        Args:
            user_instruction: Optional user's filter instruction
            filters: Optional list of predefined filters
            timeout: Optional custom timeout

        Returns:
            BuildFilterPromptResponse with built prompt
        """
        request = BuildFilterPromptRequest(
            user_instruction=user_instruction,
            filters=filters,
        )
        return await self._request_with_retry(
            AGENT_SUBJECTS["build_filter_prompt"],
            request,
            BuildFilterPromptResponse,
            timeout,
        )
