"""NATS RPC handlers for AI agents."""

from faststream import Context
from faststream.nats import NatsBroker
from loguru import logger
from shared.context import set_request_id
from shared.events.agent_requests import (
    AGENT_SUBJECTS,
    AgentErrorResponse,
    BuildFilterPromptRequest,
    BuildFilterPromptResponse,
    BulletSummaryRequest,
    BulletSummaryResponse,
    ChatMessageRequest,
    ChatMessageResponse,
    CurrentFeedInfo,
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
    FilterConfig,
    PostTitleRequest,
    PostTitleResponse,
    SourceValidationResult,
    UnseenSummaryRequest,
    UnseenSummaryResponse,
    ViewConfig,
    ViewGeneratorRequest,
    ViewGeneratorResponse,
    ViewPromptTransformerRequest,
    ViewPromptTransformerResponse,
)
from shared.nats.logging import (
    log_rpc_handler_end,
    log_rpc_handler_start,
    nats_timing,
)

from ..ai_agents.chat_message_agent import ChatMessageAgent
from ..ai_agents.feed_description_agent import FeedDescriptionAgent
from ..ai_agents.feed_filter_agent import FeedFilterAgent
from ..ai_agents.feed_summary_agent import FeedSummaryAgent
from ..ai_agents.feed_tags_agent import FeedTagsAgent
from ..ai_agents.feed_title_agent import FeedTitleAgent
from ..ai_agents.post_title_agent import PostTitleAgent
from ..ai_agents.prompt_builder import build_filter_prompt
from ..ai_agents.prompts import SUMMARY_BULLET_PROMPT
from ..ai_agents.unseen_summary_agent import UnseenSummaryAgent
from ..ai_agents.view_generator_agent import ViewGeneratorAgent
from ..ai_agents.view_prompt_transformer_agent import ViewPromptTransformerAgent
from ..config import settings

TRANSIENT_ERROR_PATTERNS = ("timed out", "timeout", "NoRespondersError")


def _log_rpc_error(handler_name: str, error: Exception) -> None:
    """Log RPC error with appropriate level based on error type.

    Transient errors (timeouts, no responders) are logged as WARNING.
    Other errors are logged as ERROR.
    """
    error_str = str(error).lower()
    is_transient = any(
        pattern.lower() in error_str for pattern in TRANSIENT_ERROR_PATTERNS
    )

    if is_transient:
        logger.warning(f"RPC {handler_name} transient error: {error}")
    else:
        logger.error(f"RPC {handler_name} error: {error}", exc_info=True)


_feed_filter_agent: FeedFilterAgent | None = None
_feed_tags_agent: FeedTagsAgent | None = None
_feed_summary_agent: FeedSummaryAgent | None = None
_feed_title_agent: FeedTitleAgent | None = None
_feed_description_agent: FeedDescriptionAgent | None = None
_chat_message_agent: ChatMessageAgent | None = None
_unseen_summary_agent: UnseenSummaryAgent | None = None
_view_generator_agent: ViewGeneratorAgent | None = None
_post_title_agent: PostTitleAgent | None = None
_view_prompt_transformer_agent: ViewPromptTransformerAgent | None = None


def get_feed_filter_agent() -> FeedFilterAgent:
    """Get or create FeedFilterAgent instance."""
    global _feed_filter_agent
    if _feed_filter_agent is None:
        _feed_filter_agent = FeedFilterAgent(
            api_key=settings.feed_filter_api_key or None,
            base_url=settings.feed_filter_base_url or None,
            model=settings.feed_filter_model or None,
        )
    return _feed_filter_agent


def get_feed_tags_agent() -> FeedTagsAgent:
    """Get or create FeedTagsAgent instance."""
    global _feed_tags_agent
    if _feed_tags_agent is None:
        _feed_tags_agent = FeedTagsAgent(
            api_key=settings.feed_tags_api_key or None,
            base_url=settings.feed_tags_base_url or None,
            model=settings.feed_tags_model or None,
        )
    return _feed_tags_agent


def get_feed_summary_agent() -> FeedSummaryAgent:
    """Get or create FeedSummaryAgent instance."""
    global _feed_summary_agent
    if _feed_summary_agent is None:
        _feed_summary_agent = FeedSummaryAgent(
            api_key=settings.feed_summary_api_key or None,
            base_url=settings.feed_summary_base_url or None,
            model=settings.feed_summary_model or None,
        )
    return _feed_summary_agent


def get_feed_title_agent() -> FeedTitleAgent:
    """Get or create FeedTitleAgent instance."""
    global _feed_title_agent
    if _feed_title_agent is None:
        _feed_title_agent = FeedTitleAgent(
            api_key=settings.feed_title_api_key or None,
            base_url=settings.feed_title_base_url or None,
            model=settings.feed_title_model or None,
        )
    return _feed_title_agent


def get_feed_description_agent() -> FeedDescriptionAgent:
    """Get or create FeedDescriptionAgent instance."""
    global _feed_description_agent
    if _feed_description_agent is None:
        _feed_description_agent = FeedDescriptionAgent(
            api_key=settings.feed_description_api_key or None,
            base_url=settings.feed_description_base_url or None,
            model=settings.feed_description_model or None,
        )
    return _feed_description_agent


def get_chat_message_agent() -> ChatMessageAgent:
    """Get or create ChatMessageAgent instance."""
    global _chat_message_agent
    if _chat_message_agent is None:
        _chat_message_agent = ChatMessageAgent(
            api_key=settings.chat_message_api_key or None,
            base_url=settings.chat_message_base_url or None,
            model=settings.chat_message_model or None,
        )
    return _chat_message_agent


def get_unseen_summary_agent() -> UnseenSummaryAgent:
    """Get or create UnseenSummaryAgent instance."""
    global _unseen_summary_agent
    if _unseen_summary_agent is None:
        _unseen_summary_agent = UnseenSummaryAgent(
            api_key=settings.unseen_summary_api_key or None,
            base_url=settings.unseen_summary_base_url or None,
            model=settings.unseen_summary_model or None,
        )
    return _unseen_summary_agent


def get_view_generator_agent() -> ViewGeneratorAgent:
    """Get or create ViewGeneratorAgent instance."""
    global _view_generator_agent
    if _view_generator_agent is None:
        _view_generator_agent = ViewGeneratorAgent(
            api_key=settings.view_generator_api_key or None,
            base_url=settings.view_generator_base_url or None,
            model=settings.view_generator_model or None,
        )
    return _view_generator_agent


def get_post_title_agent() -> PostTitleAgent:
    """Get or create PostTitleAgent instance."""
    global _post_title_agent
    if _post_title_agent is None:
        _post_title_agent = PostTitleAgent(
            api_key=settings.post_title_api_key or None,
            base_url=settings.post_title_base_url or None,
            model=settings.post_title_model or None,
        )
    return _post_title_agent


def get_view_prompt_transformer_agent() -> ViewPromptTransformerAgent:
    """Get or create ViewPromptTransformerAgent instance."""
    global _view_prompt_transformer_agent
    if _view_prompt_transformer_agent is None:
        _view_prompt_transformer_agent = ViewPromptTransformerAgent(
            api_key=settings.view_prompt_transformer_api_key or None,
            base_url=settings.view_prompt_transformer_base_url or None,
            model=settings.view_prompt_transformer_model or None,
        )
    return _view_prompt_transformer_agent


def setup_agent_handlers(broker: NatsBroker) -> None:
    """Setup NATS RPC handlers for all AI agents."""

    @broker.subscriber(AGENT_SUBJECTS["feed_filter"], max_workers=15)
    async def handle_feed_filter(
        request: FeedFilterRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> FeedFilterResponse | AgentErrorResponse:
        """Handle FeedFilterAgent.evaluate_post requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["feed_filter"], "feed_filter", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_feed_filter_agent()
                    result = await agent.evaluate_post(
                        filter_prompt=request.filter_prompt,
                        post_content=request.post_content,
                        user_id=request.user_id,
                    )
                response = FeedFilterResponse(
                    result=result.result,
                    title=result.title,
                    explanation=result.explanation,
                )
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("feed_filter", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["feed_tags"], max_workers=15)
    async def handle_feed_tags(
        request: FeedTagsRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> FeedTagsResponse | AgentErrorResponse:
        """Handle FeedTagsAgent.generate_tags requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["feed_tags"], "feed_tags", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_feed_tags_agent()
                    tags = await agent.generate_tags(
                        raw_posts_content=request.raw_posts_content,
                        prompt_text=request.prompt_text,
                        feed_type=request.feed_type,
                        available_tags=request.available_tags,
                        user_id=request.user_id,
                    )
                response = FeedTagsResponse(tags=tags)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("feed_tags", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["feed_summary"], max_workers=15)
    async def handle_feed_summary(
        request: FeedSummaryRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> FeedSummaryResponse | AgentErrorResponse:
        """Handle FeedSummaryAgent.summarize_posts requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["feed_summary"], "feed_summary", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_feed_summary_agent()
                    result = await agent.summarize_posts(
                        user_prompt=request.user_prompt,
                        posts_content=request.posts_content,
                        title=request.title,
                        user_id=request.user_id,
                    )
                response = FeedSummaryResponse(
                    title=result.title,
                    summary=result.summary,
                )
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("feed_summary", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["feed_title"], max_workers=15)
    async def handle_feed_title(
        request: FeedTitleRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> FeedTitleResponse | AgentErrorResponse:
        """Handle FeedTitleAgent.generate_feed_title requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["feed_title"], "feed_title", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_feed_title_agent()
                    title = await agent.generate_feed_title(
                        feed_filters=request.feed_filters,
                        sample_posts=request.sample_posts,
                        user_id=request.user_id,
                    )
                response = FeedTitleResponse(title=title)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("feed_title", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["feed_description"], max_workers=15)
    async def handle_feed_description(
        request: FeedDescriptionRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> FeedDescriptionResponse | AgentErrorResponse:
        """Handle FeedDescriptionAgent.generate_description requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["feed_description"],
                "feed_description",
                request,
                request_id,
            )
            try:
                with nats_timing() as timing:
                    agent = get_feed_description_agent()
                    description = await agent.generate_description(
                        prompt=request.prompt,
                        sources=request.sources,
                        feed_type=request.feed_type,
                        user_id=request.user_id,
                    )
                response = FeedDescriptionResponse(description=description)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("feed_description", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["chat_message"], max_workers=15)
    async def handle_chat_message(
        request: ChatMessageRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> ChatMessageResponse | AgentErrorResponse:
        """Handle ChatMessageAgent.process_message requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["chat_message"], "chat_message", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_chat_message_agent()
                    ai_response, validation_results = await agent.process_message(
                        user_message=request.user_message,
                        current_state=request.current_state,
                        chat_history=request.chat_history,
                        user_id=request.user_id,
                    )

                    current_feed_info = None
                    if ai_response.current_feed_info:
                        current_feed_info = CurrentFeedInfo(
                            prompt=ai_response.current_feed_info.prompt,
                            sources=ai_response.current_feed_info.sources,
                            source_types=ai_response.current_feed_info.source_types,
                            type=ai_response.current_feed_info.type,
                            tags=ai_response.current_feed_info.tags,
                            digest_interval=ai_response.current_feed_info.digest_interval,
                        )

                response = ChatMessageResponse(
                    response=ai_response.response,
                    current_feed_info=current_feed_info,
                    ready_for_creation=ai_response.ready_for_creation,
                    suggestions=ai_response.suggestions,
                    validation_results=[
                        SourceValidationResult(
                            url=vr.url,
                            valid=vr.valid,
                            source_type=vr.source_type,
                            message=vr.message,
                            detected_feed_url=vr.detected_feed_url,
                        )
                        for vr in validation_results
                    ],
                )
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("chat_message", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["unseen_summary"], max_workers=15)
    async def handle_unseen_summary(
        request: UnseenSummaryRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> UnseenSummaryResponse | AgentErrorResponse:
        """Handle UnseenSummaryAgent.summarize_unseen requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["unseen_summary"], "unseen_summary", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_unseen_summary_agent()
                    result = await agent.summarize_unseen(
                        posts_data=request.posts_data,
                        user_id=request.user_id,
                    )
                response = UnseenSummaryResponse(
                    title=result.title,
                    summary=result.summary,
                    full_text=result.full_text,
                )
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("unseen_summary", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["view_generator"], max_workers=15)
    async def handle_view_generator(
        request: ViewGeneratorRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> ViewGeneratorResponse | AgentErrorResponse:
        """Handle ViewGeneratorAgent.generate_view requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["view_generator"], "view_generator", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_view_generator_agent()
                    content = await agent.generate_view(
                        content=request.content,
                        view_prompt=request.view_prompt,
                        user_id=request.user_id,
                    )
                response = ViewGeneratorResponse(content=content)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("view_generator", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["post_title"], max_workers=15)
    async def handle_post_title(
        request: PostTitleRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> PostTitleResponse | AgentErrorResponse:
        """Handle PostTitleAgent.generate_title requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["post_title"], "post_title", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_post_title_agent()
                    title = await agent.generate_title(
                        post_content=request.post_content,
                        user_id=request.user_id,
                    )
                response = PostTitleResponse(title=title)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("post_title", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["view_prompt_transformer"], max_workers=15)
    async def handle_view_prompt_transformer(
        request: ViewPromptTransformerRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> ViewPromptTransformerResponse | AgentErrorResponse:
        """Handle ViewPromptTransformerAgent.transform requests."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["view_prompt_transformer"],
                "view_prompt_transformer",
                request,
                request_id,
            )
            try:
                with nats_timing() as timing:
                    agent = get_view_prompt_transformer_agent()
                    result = await agent.transform(
                        views=request.views,
                        filters=request.filters,
                        context_posts=request.context_posts,
                        user_id=request.user_id,
                    )
                    # Filter out views/filters with empty or too short prompts (min 5 chars)
                    valid_views = [
                        ViewConfig(name=v.name, prompt=v.prompt)
                        for v in result.views
                        if v.prompt and len(v.prompt.strip()) >= 5
                    ]
                    valid_filters = [
                        FilterConfig(name=f.name, prompt=f.prompt)
                        for f in result.filters
                        if f.prompt and len(f.prompt.strip()) >= 5
                    ]
                response = ViewPromptTransformerResponse(
                    views=valid_views,
                    filters=valid_filters,
                )
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("view_prompt_transformer", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["bullet_summary"], max_workers=15)
    async def handle_bullet_summary(
        request: BulletSummaryRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> BulletSummaryResponse | AgentErrorResponse:
        """Handle bullet point summary generation using ViewGeneratorAgent."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["bullet_summary"], "bullet_summary", request, request_id
            )
            try:
                with nats_timing() as timing:
                    agent = get_view_generator_agent()
                    content = await agent.generate_view(
                        content=request.content,
                        view_prompt=SUMMARY_BULLET_PROMPT,
                        user_id=request.user_id,
                    )
                response = BulletSummaryResponse(content=content)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("bullet_summary", e)
                return AgentErrorResponse(error=str(e))

    @broker.subscriber(AGENT_SUBJECTS["build_filter_prompt"], max_workers=15)
    async def handle_build_filter_prompt(
        request: BuildFilterPromptRequest,
        request_id: str | None = Context("message.headers.X-Request-ID", default=None),
    ) -> BuildFilterPromptResponse | AgentErrorResponse:
        """Handle filter prompt building."""
        set_request_id(request_id)
        with logger.contextualize(request_id=request_id):
            ctx = log_rpc_handler_start(
                AGENT_SUBJECTS["build_filter_prompt"],
                "build_filter_prompt",
                request,
                request_id,
            )
            try:
                with nats_timing() as timing:
                    prompt = build_filter_prompt(
                        user_instruction=request.user_instruction,
                        filters=request.filters,
                    )
                response = BuildFilterPromptResponse(prompt=prompt)
                log_rpc_handler_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response
            except Exception as e:
                log_rpc_handler_end(ctx, 0, success=False, error=str(e))
                _log_rpc_error("build_filter_prompt", e)
                return AgentErrorResponse(error=str(e))

    logger.info(f"Registered {len(AGENT_SUBJECTS)} agent RPC handlers")
