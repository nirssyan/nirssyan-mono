"""Models for marking posts as seen."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class MarkPostsSeenRequest(BaseModel):
    """Request model for marking posts as seen."""

    post_ids: list[UUID] = Field(
        ...,
        min_length=1,
        description="List of post IDs to mark as seen",
        examples=[
            [
                "550e8400-e29b-41d4-a716-446655440001",
                "550e8400-e29b-41d4-a716-446655440002",
            ]
        ],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "post_ids": [
                        "550e8400-e29b-41d4-a716-446655440001",
                        "550e8400-e29b-41d4-a716-446655440002",
                        "550e8400-e29b-41d4-a716-446655440003",
                    ]
                }
            ]
        }
    )


class MarkPostsSeenResponse(BaseModel):
    """Response model for marking posts as seen."""

    success: bool = Field(examples=[True, False])
    marked_count: int = Field(
        ..., description="Number of posts marked as seen", examples=[3, 1, 10]
    )
    message: str = Field(examples=["3 posts marked as seen", "No posts marked"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "marked_count": 3,
                    "message": "3 posts marked as seen",
                }
            ]
        }
    )
