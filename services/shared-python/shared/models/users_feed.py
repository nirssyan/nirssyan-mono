"""Models for users_feeds operations."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CreateUsersFeedRequest(BaseModel):
    """Request model for creating user-feed association."""

    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"feed_id": "550e8400-e29b-41d4-a716-446655440001"}]
        }
    )


class CreateUsersFeedResponse(BaseModel):
    """Response model for user-feed creation."""

    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Feed added to user's collection", "Feed already in collection"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"success": True, "message": "Feed added to user's collection"}
            ]
        }
    )


class DeleteUsersFeedResponse(BaseModel):
    """Response model for user-feed deletion."""

    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Feed removed from collection", "Feed not found in collection"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"success": True, "message": "Feed removed from collection"}]
        }
    )
