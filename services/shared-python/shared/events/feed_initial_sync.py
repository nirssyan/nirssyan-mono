"""Event schema for feed initial sync notifications."""

from datetime import datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class FeedInitialSyncEvent(BaseModel):
    """Event published after initial sync when creating a new feed.

    This event triggers the processor to create feed_posts from existing
    raw_posts without AI processing - just copy posts as-is for immediate display.

    Published by:
        - makefeed-api: After creating a feed and syncing initial posts

    Consumed by:
        - makefeed-processor: Creates feed_posts from raw_posts
    """

    event_type: Literal["feed.initial_sync"] = "feed.initial_sync"
    event_id: UUID = Field(default_factory=uuid4)
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    feed_id: UUID = Field(description="ID of the newly created feed")
    prompt_id: UUID = Field(description="ID of the prompt linked to the feed")
    raw_feed_id: UUID = Field(description="ID of the raw feed with source posts")
    raw_post_count: int = Field(description="Number of raw posts to process")
    source_identifier: str = Field(
        description="Source identifier (@channel for TG, URL for RSS/Web)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "event_type": "feed.initial_sync",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "timestamp": "2025-01-15T10:30:00Z",
                "feed_id": "123e4567-e89b-12d3-a456-426614174000",
                "prompt_id": "223e4567-e89b-12d3-a456-426614174000",
                "raw_feed_id": "323e4567-e89b-12d3-a456-426614174000",
                "raw_post_count": 10,
                "source_identifier": "@durov",
            }
        }
    )
