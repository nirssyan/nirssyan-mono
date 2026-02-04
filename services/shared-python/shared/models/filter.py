"""Pydantic models for feed filtering operations."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from shared.enums import FeedType


class RSSItem(BaseModel):
    """Model for individual RSS feed item."""

    title: str | None = None
    link: str | None = None
    description: str | None = None
    pub_date: datetime | None = None
    guid: str | None = None
    content_encoded: str | None = None
    images: list[str] = Field(default_factory=list)
    enclosure_url: str | None = None


class FilterPromptData(BaseModel):
    """Model for filter prompt data from database."""

    prompt_id: UUID
    prompt: str
    last_execution: datetime | None
    feed_id: UUID
    sources: list[str] = Field(
        default_factory=list, description="List of RSS feed sources"
    )


class FilteredPostData(BaseModel):
    """Model for post data that passed filtering."""

    title: str = Field(max_length=40, description="Brief post title")
    full_text: str = Field(description="Full post content")
    summary: str = Field(description="AI-generated explanation")
    image_url: str | None = None
    source_url: str = Field(description="Original URL of the post")
    feed_id: UUID = Field(description="ID of the feed this post belongs to")


class ProcessingResult(BaseModel):
    """Model for feed processing results."""

    prompt_id: UUID
    processed_count: int = Field(default=0, description="Number of posts processed")
    filtered_count: int = Field(
        default=0, description="Number of posts that passed filter"
    )
    created_count: int = Field(
        default=0, description="Number of posts created in database"
    )
    errors: list[str] = Field(
        default_factory=list, description="List of errors encountered"
    )


class FeedProcessingRequest(BaseModel):
    """Model for feed processing request."""

    feed_type: FeedType | None = Field(
        default=FeedType.SINGLE_POST,
        description="Type of feed processing: SINGLE_POST or DIGEST",
    )
    prompt_ids: list[UUID] | None = Field(
        default=None,
        description="Optional list of specific prompt IDs to process. If None, all prompts will be processed.",
    )
    force_update: bool | None = Field(
        default=False,
        description="Whether to force update even if prompts were recently processed",
    )


class FeedProcessingResponse(BaseModel):
    """Model for feed processing response."""

    success: bool
    message: str
    results: list[ProcessingResult] = Field(default_factory=list)
    total_processed: int = Field(default=0)
    total_created: int = Field(default=0)
    request_id: str | None = Field(default=None, description="Request ID for tracing")
