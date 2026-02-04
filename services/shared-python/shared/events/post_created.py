"""Event schema for post created notifications."""

from datetime import datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class PostCreatedEvent(BaseModel):
    """Event published when a post is created in a feed.

    This event notifies the API to send WebSocket notification to the user.

    Published by:
        - makefeed-processor: After creating posts during processing

    Consumed by:
        - makefeed-api: Sends WebSocket notification to feed owner
    """

    event_type: Literal["post.created"] = "post.created"
    event_id: UUID = Field(default_factory=uuid4)
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    post_id: UUID = Field(description="ID of the created post")
    feed_id: UUID = Field(description="ID of the feed containing the post")
    user_id: UUID = Field(description="ID of the feed owner to notify")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "event_type": "post.created",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "timestamp": "2025-01-15T10:30:00Z",
                "post_id": "123e4567-e89b-12d3-a456-426614174001",
                "feed_id": "123e4567-e89b-12d3-a456-426614174000",
                "user_id": "223e4567-e89b-12d3-a456-426614174000",
            }
        }
    )
