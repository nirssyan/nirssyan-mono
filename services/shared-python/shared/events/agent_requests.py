"""Request/Response schemas for AI agents via NATS RPC."""

from typing import Any

from pydantic import BaseModel, Field, field_validator

from shared.models.common import LocalizedName


class FeedFilterRequest(BaseModel):
    """Request for FeedFilterAgent.evaluate_post."""

    filter_prompt: str
    post_content: str
    user_id: str | None = None


class FeedFilterResponse(BaseModel):
    """Response from FeedFilterAgent."""

    result: bool
    title: str
    explanation: str


class FeedTagsRequest(BaseModel):
    """Request for FeedTagsAgent.generate_tags."""

    raw_posts_content: list[str]
    prompt_text: str | None = None
    feed_type: str
    available_tags: list[str]
    user_id: str | None = None


class FeedTagsResponse(BaseModel):
    """Response from FeedTagsAgent."""

    tags: list[str]


class FeedSummaryRequest(BaseModel):
    """Request for FeedSummaryAgent.summarize_posts."""

    user_prompt: str
    posts_content: list[str]
    title: str = "Summary"
    user_id: str | None = None


class FeedSummaryResponse(BaseModel):
    """Response from FeedSummaryAgent."""

    title: str
    summary: str


class FeedTitleRequest(BaseModel):
    """Request for FeedTitleAgent.generate_feed_title."""

    feed_filters: dict[str, Any]
    sample_posts: list[str]
    user_id: str | None = None


class FeedTitleResponse(BaseModel):
    """Response from FeedTitleAgent."""

    title: str


class FeedDescriptionRequest(BaseModel):
    """Request for FeedDescriptionAgent.generate_description."""

    prompt: str | None = None
    sources: list[str] | None = None
    feed_type: str | None = None
    user_id: str | None = None


class FeedDescriptionResponse(BaseModel):
    """Response from FeedDescriptionAgent."""

    description: str


class ChatMessageRequest(BaseModel):
    """Request for ChatMessageAgent.process_message."""

    user_message: str
    current_state: dict[str, Any] | None = None
    chat_history: list[dict[str, Any]] | None = None
    user_id: str | None = None


class SourceValidationResult(BaseModel):
    """Result of URL validation."""

    url: str
    valid: bool
    source_type: str | None = None
    message: str | None = None
    detected_feed_url: str | None = None


class CurrentFeedInfo(BaseModel):
    """Current feed configuration from AI response."""

    prompt: str | None = None
    sources: list[str] | None = None
    source_types: list[str | None] | None = None
    type: str | None = None
    tags: list[str] | None = None
    digest_interval: str | None = None


class ChatMessageResponse(BaseModel):
    """Response from ChatMessageAgent."""

    response: str
    current_feed_info: CurrentFeedInfo | None = None
    ready_for_creation: bool = False
    suggestions: list[str] = Field(default_factory=list)
    validation_results: list[SourceValidationResult] = Field(default_factory=list)


class UnseenSummaryRequest(BaseModel):
    """Request for UnseenSummaryAgent.summarize_unseen."""

    posts_data: list[dict[str, Any]]
    user_id: str | None = None


class UnseenSummaryResponse(BaseModel):
    """Response from UnseenSummaryAgent."""

    title: str
    summary: str
    full_text: str


class ViewGeneratorRequest(BaseModel):
    """Request for ViewGeneratorAgent.generate_view."""

    content: str
    view_prompt: str
    user_id: str | None = None


class ViewGeneratorResponse(BaseModel):
    """Response from ViewGeneratorAgent."""

    content: str

    @field_validator("content", mode="before")
    @classmethod
    def convert_list_to_string(cls, v: str | list[str]) -> str:
        """Convert list to newline-separated string (LLM sometimes returns list)."""
        if isinstance(v, list):
            return "\n".join(str(item) for item in v)
        return v


class PostTitleRequest(BaseModel):
    """Request for PostTitleAgent.generate_title."""

    post_content: str
    user_id: str | None = None


class PostTitleResponse(BaseModel):
    """Response from PostTitleAgent."""

    title: str


class AgentErrorResponse(BaseModel):
    """Error response from any agent."""

    error: str
    success: bool = False


class ViewConfig(BaseModel):
    """Single view configuration for dynamic post rendering."""

    name: LocalizedName
    prompt: str


class FilterConfig(BaseModel):
    """Single filter configuration for dynamic post filtering."""

    name: LocalizedName
    prompt: str


class ViewPromptTransformerRequest(BaseModel):
    """Request for ViewPromptTransformerAgent.transform."""

    views: list[str] = Field(default_factory=list)
    filters: list[str] = Field(default_factory=list)
    context_posts: list[str] | None = None
    user_id: str | None = None


class ViewPromptTransformerResponse(BaseModel):
    """Response from ViewPromptTransformerAgent."""

    views: list[ViewConfig] = Field(default_factory=list)
    filters: list[FilterConfig] = Field(default_factory=list)


class BulletSummaryRequest(BaseModel):
    """Request for generating bullet point summary."""

    content: str
    user_id: str | None = None


class BulletSummaryResponse(BaseModel):
    """Response with bullet point summary."""

    content: str


class BuildFilterPromptRequest(BaseModel):
    """Request for building enhanced filter prompt."""

    user_instruction: str | None = None
    filters: list[str] | None = None


class BuildFilterPromptResponse(BaseModel):
    """Response with built filter prompt."""

    prompt: str


AGENT_SUBJECTS = {
    "feed_filter": "agents.feed.filter",
    "feed_tags": "agents.feed.tags",
    "feed_summary": "agents.feed.summary",
    "feed_title": "agents.feed.title",
    "feed_description": "agents.feed.description",
    "chat_message": "agents.chat.message",
    "unseen_summary": "agents.feed.unseen_summary",
    "view_generator": "agents.feed.view_generator",
    "post_title": "agents.post.title",
    "view_prompt_transformer": "agents.feed.view_prompt_transformer",
    "bullet_summary": "agents.feed.bullet_summary",
    "build_filter_prompt": "agents.util.build_filter_prompt",
}
