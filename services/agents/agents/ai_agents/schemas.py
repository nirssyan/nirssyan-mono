"""Pydantic schemas for AI agent responses."""

import logging
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

from shared.models.common import LocalizedName

logger = logging.getLogger(__name__)


class PromptConfigSchema(BaseModel):
    """Prompt configuration with instruction and filters.

    Defaults:
        instruction: Optional instruction. None for SINGLE_POST (simple subscription),
                    "Создай краткую сводку" for DIGEST types. Can be overridden during feed creation.
        filters: ["remove_ads"] is the most commonly used filter across all feed types.
                Additional filters can be added as the system evolves.
    """

    instruction: str | None = None
    filters: list[str] = Field(default_factory=lambda: ["remove_ads"])


class ViewConfig(BaseModel):
    """Single view configuration for dynamic post rendering."""

    name: LocalizedName = Field(
        description="Localized name with en/ru versions (snake_case identifiers)",
    )
    prompt: str = Field(
        description="AI instruction for generating this view",
        min_length=5,
    )


class FilterConfig(BaseModel):
    """Single filter configuration for dynamic post filtering."""

    name: LocalizedName = Field(
        description="Localized name with en/ru versions (snake_case identifiers)",
    )
    prompt: str = Field(
        description="Question to evaluate post (YES = include, NO = filter out)",
        min_length=5,
    )


class ViewPromptTransformerResponse(BaseModel):
    """Response from ViewPromptTransformerAgent."""

    views: list[ViewConfig] = Field(default_factory=list)
    filters: list[FilterConfig] = Field(default_factory=list)


class CurrentFeedInfoSchema(BaseModel):
    """Current feed configuration info for refactored 2-type system (SINGLE_POST/DIGEST).

    This is the NEW schema used in the refactored chat flow with simplified feed types.
    Use this for ChatMessageAIResponse starting from the feed types refactoring.
    """

    feed_type: Literal["SINGLE_POST", "DIGEST"] | None = None
    source: str | None = None
    source_types: dict[str, str] | None = Field(
        default=None,
        description="Mapping of source URL to parser type (TELEGRAM, RSS_FEEDPARSER, SITEMAP, HTML, TRAFILATURA). Built from validation_results.",
    )
    prompt_config: PromptConfigSchema
    views: list[str] | None = Field(
        default=None,
        description="User-defined view descriptions (e.g., ['read as if I'm 5', 'summarize'])",
    )
    filters: list[str] | None = Field(
        default=None,
        description="User-defined filter descriptions (e.g., ['no ads', 'only AI'])",
    )


class ChatMessageAIResponse(BaseModel):
    """Response schema for chat message AI agent."""

    response: str = Field(
        description="AI response text to the user in their language",
        min_length=1,
    )
    current_feed_info: CurrentFeedInfoSchema = Field(
        description="Current state of feed configuration",
    )
    suggestions: list[str] = Field(
        description="List of contextual suggestions for the user",
        min_length=0,
        max_length=10,
    )
    is_ready_to_create_feed: bool = False


class FeedFilterResponse(BaseModel):
    """Response schema for feed filter agent."""

    result: bool = Field(
        description="Whether the post passes the filter criteria (true/false)"
    )
    title: str = Field(
        description="Brief post title reflecting the main idea (max 60 characters)",
        max_length=60,
    )
    explanation: str = Field(
        description="Detailed explanation of why the post passes or fails the filter",
        min_length=10,
    )

    @field_validator("title", mode="before")
    @classmethod
    def truncate_title(cls, v: Any) -> Any:
        """Truncate title to 60 characters if needed (defense in depth)."""
        if isinstance(v, str) and len(v) > 60:
            return v[:60]
        return v


class FeedSummaryResponse(BaseModel):
    """Response schema for feed summary agent."""

    title: str = Field(
        description="Brief title for the summary post (max 60 characters)",
        max_length=60,
        min_length=1,
    )
    summary: str = Field(
        description="Comprehensive summary text based on all aggregated posts",
        min_length=10,
    )

    @field_validator("title", mode="before")
    @classmethod
    def truncate_title(cls, v: Any) -> Any:
        """Truncate title to 60 characters if needed (defense in depth)."""
        if isinstance(v, str) and len(v) > 60:
            return v[:60]
        return v


class FeedCommentResponse(BaseModel):
    """Response schema for feed comment agent."""

    comment: str = Field(
        description="AI-generated comment about the post content",
        min_length=10,
    )
    title: str = Field(
        description="Brief post title reflecting the main idea (max 60 characters)",
        max_length=60,
    )

    @field_validator("title", mode="before")
    @classmethod
    def truncate_title(cls, v: Any) -> Any:
        """Truncate title to 60 characters if needed (defense in depth)."""
        if isinstance(v, str) and len(v) > 60:
            return v[:60]
        return v


class PostTitleResponse(BaseModel):
    """Response schema for post title generation agent."""

    title: str = Field(
        description="Brief post title reflecting the main idea (max 60 characters)",
        max_length=60,
        min_length=1,
    )

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, v: Any) -> Any:
        """Normalize and truncate title (defense in depth).

        Handles cases where LLM returns nested dict like {'title': 'actual title'}.
        """
        # Unwrap nested dict: {'title': 'value'} -> 'value'
        if isinstance(v, dict) and "title" in v:
            v = v["title"]

        # Truncate to 60 characters if needed
        if isinstance(v, str) and len(v) > 60:
            return v[:60]
        return v


class ViewGeneratorResponse(BaseModel):
    """Response schema for view generator agent.

    Transforms content according to a view-specific prompt.
    """

    content: str = Field(
        description="Generated view content based on the view prompt",
        min_length=1,
    )

    @field_validator("content", mode="before")
    @classmethod
    def convert_list_to_string(cls, v: str | list[str]) -> str:
        """Convert list of strings to newline-separated string.

        Some LLMs return bullet points as a list instead of a string.
        This validator handles that case gracefully.
        """
        if isinstance(v, list):
            return "\n".join(str(item) for item in v)
        return v


class FeedTitleResponse(BaseModel):
    """Response schema for feed title generation agent."""

    title: str = Field(
        description="Brief feed title (1-2 words) describing the feed's purpose",
        max_length=30,
        min_length=1,
    )

    @field_validator("title", mode="before")
    @classmethod
    def truncate_title(cls, v: Any) -> Any:
        """Truncate title to 30 characters if needed (defense in depth)."""
        if isinstance(v, str) and len(v) > 30:
            return v[:30]
        return v


class FeedDescriptionResponse(BaseModel):
    """Response schema for feed description generation agent."""

    description: str = Field(
        description="Detailed feed description (2-3 sentences describing the feed purpose, sources, and type)",
        min_length=10,
        max_length=500,
    )


class SourceValidationInput(BaseModel):
    """Input schema for source validation tool."""

    url: str = Field(
        description="Source URL to validate (Telegram channel, RSS feed, or website)",
        min_length=1,
    )


class SourceValidationOutput(BaseModel):
    """Output schema for source validation tool."""

    url: str = Field(description="Original URL from user message")
    valid: bool = Field(description="Whether the source is valid and can be parsed")
    source_type: str | None = Field(
        default=None,
        description="Type of parser detected (TELEGRAM, RSS_FEEDPARSER, SITEMAP, HTML, TRAFILATURA) or null if invalid",
    )
    message: str = Field(
        description="Human-readable message about validation result",
        min_length=1,
    )
    detected_feed_url: str | None = Field(
        default=None,
        description="Actual feed URL if different from input (e.g., RSS feed URL discovered from website)",
    )


class FeedTagsResponse(BaseModel):
    """Response schema for feed tags generation agent."""

    tags: list[str] = Field(
        description="List of 1-4 most relevant tags from the provided list of 31 available tags",
        # Note: min_length and max_length constraints handled by custom validator with auto-truncation
    )
    reasoning: str = Field(
        description="Brief explanation of why these tags were selected based on content analysis",
        min_length=10,
    )

    @field_validator("tags", mode="after")
    @classmethod
    def validate_tags_count(cls, v: list[str]) -> list[str]:
        """Validate that tags list contains 1-4 elements.

        If LLM returns more than 4 tags (ignoring prompt constraints),
        automatically truncate to first 4 with a warning instead of failing.
        """
        if len(v) < 1:
            raise ValueError("Minimum 1 tag required")
        if len(v) > 4:
            logger.warning(
                f"⚠️ LLM returned {len(v)} tags (violating max=4 constraint). "
                f"Auto-truncating to first 4 tags. Original: {v}"
            )
            return v[:4]  # Auto-truncate instead of raising error
        return v


class UnseenSummaryResponse(BaseModel):
    """Response schema for unseen posts summary agent.

    Creates a narrative digest from multiple unseen posts with:
    - title: short catchy title describing digest content (3-7 words)
    - summary: narrative summary of what happened across all posts
    - full_text: complete original posts content
    """

    title: str = Field(
        description="Short catchy title for the digest (3-7 words), e.g. 'Победы, погода, машины' or 'История о путешествии на Бали'",
        min_length=3,
        max_length=100,
    )
    summary: str = Field(
        description="Narrative summary of key events and themes across all posts (not bullet points)",
        min_length=10,
    )
    full_text: str = Field(
        description="Complete content of all posts with headers",
        min_length=10,
    )


class PostFacts(BaseModel):
    """Facts extracted from a single post."""

    post_index: int = Field(description="Post number (1, 2, 3...)")
    title: str = Field(
        description="Short title (3-5 words)", min_length=1, max_length=100
    )
    topic: str = Field(
        description="Topic category for clustering (2-4 words)",
        min_length=1,
        max_length=50,
    )
    facts: list[str] = Field(
        description="Key facts (3-5 items)", min_length=1, max_length=10
    )


class FactsExtractionResponse(BaseModel):
    """Response from facts extraction stage."""

    posts: list[PostFacts] = Field(description="List of extracted facts per post")


class SynthesisResponse(BaseModel):
    """Response from synthesis stage (title + summary only)."""

    title: str = Field(
        description="Catchy digest title (3-7 words)",
        min_length=3,
        max_length=100,
    )
    summary: str = Field(
        description="Narrative markdown summary (3-5 paragraphs)",
        min_length=10,
    )
