"""Event schema for feed creation background processing."""

from datetime import UTC, datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class FeedCreatedEvent(BaseModel):
    """Event published when a new feed is created and needs background processing.

    This event triggers the processor to:
    1. Parse sources (Telegram channels, RSS feeds, websites)
    2. Generate AI description for the feed
    3. Transform views/filters via AI
    4. Generate tags via AI
    5. Process initial posts via AI
    6. Mark feed as finished (is_creating_finished=true)

    Published by:
        - makefeed-api: After creating feed/prompt in database

    Consumed by:
        - makefeed-processor: Performs all heavy background operations
    """

    event_type: Literal["feed.created"] = "feed.created"
    event_id: UUID = Field(default_factory=uuid4)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))

    feed_id: UUID = Field(description="ID of the newly created feed")
    prompt_id: UUID = Field(description="ID of the prompt linked to the feed")
    user_id: UUID = Field(description="ID of the user who created the feed")

    sources: list[str] = Field(description="List of source URLs/usernames to parse")
    source_types: dict[str, str] = Field(
        default_factory=dict,
        description="Mapping of source URL to source type (TELEGRAM, RSS_FEEDPARSER, etc.)",
    )

    prompt_text: str = Field(description="Prompt text for AI processing")
    feed_type: str = Field(description="Feed type (SINGLE_POST, DIGEST)")

    views_raw: list[dict] = Field(
        default_factory=list,
        description="Raw view configs for AI transformation",
    )
    filters_raw: list[dict] = Field(
        default_factory=list,
        description="Raw filter configs for AI transformation",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "event_type": "feed.created",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "timestamp": "2025-01-15T10:30:00Z",
                "feed_id": "123e4567-e89b-12d3-a456-426614174000",
                "prompt_id": "223e4567-e89b-12d3-a456-426614174000",
                "user_id": "323e4567-e89b-12d3-a456-426614174000",
                "sources": ["@durov", "https://example.com/rss"],
                "source_types": {
                    "@durov": "TELEGRAM",
                    "https://example.com/rss": "RSS_FEEDPARSER",
                },
                "prompt_text": "Выбирай только важные новости",
                "feed_type": "SINGLE_POST",
                "views_raw": [],
                "filters_raw": [],
            }
        }
    )
