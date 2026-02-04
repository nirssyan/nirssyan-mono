"""Pydantic models for tags."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TagResponse(BaseModel):
    """Response model for a single tag."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    name: str = Field(examples=["Technology", "AI", "Business"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "name": "Technology",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class TagInfo(BaseModel):
    """Nested tag information for user tags."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    name: str = Field(examples=["Technology", "AI", "Business"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"id": "550e8400-e29b-41d4-a716-446655440001", "name": "Technology"}
            ]
        }
    )


class UserTagResponse(BaseModel):
    """Response model for user's tag with tag details."""

    id: int = Field(examples=[42, 1, 100])
    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    tag: TagInfo = Field(
        examples=[{"id": "550e8400-e29b-41d4-a716-446655440001", "name": "Technology"}]
    )
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": 42,
                    "user_id": "550e8400-e29b-41d4-a716-446655440002",
                    "tag": {
                        "id": "550e8400-e29b-41d4-a716-446655440001",
                        "name": "Technology",
                    },
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class UpdateUserTagsRequest(BaseModel):
    """Request model for updating user's tags."""

    tag_ids: list[UUID] = Field(
        description="List of tag IDs to set for the user (replaces all existing tags)",
        min_length=0,
        max_length=10,
        examples=[
            [
                "550e8400-e29b-41d4-a716-446655440001",
                "550e8400-e29b-41d4-a716-446655440003",
            ]
        ],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "tag_ids": [
                        "550e8400-e29b-41d4-a716-446655440001",
                        "550e8400-e29b-41d4-a716-446655440003",
                        "550e8400-e29b-41d4-a716-446655440005",
                    ]
                }
            ]
        }
    )


class UpdateUserTagsResponse(BaseModel):
    """Response model for updating user's tags."""

    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Tags updated successfully", "Failed to update tags"]
    )
    tags_count: int = Field(examples=[3, 0, 10])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "message": "Tags updated successfully",
                    "tags_count": 3,
                }
            ]
        }
    )
