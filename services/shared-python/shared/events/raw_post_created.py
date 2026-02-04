"""Event schema for raw post creation notifications."""

from datetime import datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class RawPostCreatedEvent(BaseModel):
    """Event published after new raw posts are saved to database.

    Published by:
        - makefeed-telegram: After syncing new Telegram messages
        - makefeed-rss: After syncing new RSS articles
        - makefeed-web: After scraping new web articles

    Consumed by:
        - makefeed-processor: Triggers AI processing of new posts
    """

    event_type: Literal["raw_post.created"] = "raw_post.created"
    event_id: UUID = Field(default_factory=uuid4)
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    raw_feed_id: UUID = Field(description="ID of the raw feed containing the posts")
    raw_feed_type: Literal["TELEGRAM", "RSS", "WEB"] = Field(
        description="Type of the source: TELEGRAM, RSS, or WEB"
    )
    raw_post_ids: list[UUID] = Field(description="List of newly created raw post IDs")
    source_identifier: str = Field(
        description="Source identifier (@channel for TG, URL for RSS/Web)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "event_type": "raw_post.created",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "timestamp": "2025-01-15T10:30:00Z",
                "raw_feed_id": "123e4567-e89b-12d3-a456-426614174000",
                "raw_feed_type": "TELEGRAM",
                "raw_post_ids": [
                    "123e4567-e89b-12d3-a456-426614174001",
                    "123e4567-e89b-12d3-a456-426614174002",
                ],
                "source_identifier": "@durov",
            }
        }
    )
