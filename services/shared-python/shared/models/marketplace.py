from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class MarketplaceRequest(BaseModel):
    """Request model for marketplace endpoint."""

    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"user_id": "550e8400-e29b-41d4-a716-446655440001"}]
        }
    )


class MarketplaceFeedItem(BaseModel):
    """Model for individual feed item in marketplace."""

    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    name: str = Field(examples=["AI Research Daily", "Crypto News"])
    tags: list[str] | None = Field(
        default=None, examples=[["AI", "Research", "Tech"], None]
    )
    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440003"])
    picture: str | None = Field(
        default=None, examples=["https://storage.example.com/avatars/user123.jpg", None]
    )
    full_name: str | None = Field(default=None, examples=["John Doe", None])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "feed_id": "550e8400-e29b-41d4-a716-446655440002",
                    "name": "AI Research Daily",
                    "tags": ["AI", "Research", "Tech"],
                    "user_id": "550e8400-e29b-41d4-a716-446655440003",
                    "picture": "https://storage.example.com/avatars/user123.jpg",
                    "full_name": "John Doe",
                }
            ]
        }
    )


class MarketplaceResponse(BaseModel):
    """Response model for marketplace endpoint."""

    data: list[MarketplaceFeedItem] = Field(
        examples=[
            [
                {
                    "feed_id": "550e8400-e29b-41d4-a716-446655440002",
                    "name": "AI Research Daily",
                    "tags": ["AI"],
                    "user_id": "550e8400-e29b-41d4-a716-446655440003",
                    "picture": None,
                    "full_name": "John Doe",
                }
            ]
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "data": [
                        {
                            "feed_id": "550e8400-e29b-41d4-a716-446655440002",
                            "name": "AI Research Daily",
                            "tags": ["AI", "Research"],
                            "user_id": "550e8400-e29b-41d4-a716-446655440003",
                            "picture": "https://storage.example.com/avatars/user1.jpg",
                            "full_name": "John Doe",
                        },
                        {
                            "feed_id": "550e8400-e29b-41d4-a716-446655440004",
                            "name": "Crypto News",
                            "tags": ["Crypto", "Finance"],
                            "user_id": "550e8400-e29b-41d4-a716-446655440005",
                            "picture": "https://storage.example.com/avatars/user2.jpg",
                            "full_name": "Jane Smith",
                        },
                    ]
                }
            ]
        }
    )


class SetMarketplaceFeedsRequest(BaseModel):
    """Request model for setting feeds as marketplace feeds."""

    feed_ids: list[UUID] = Field(
        examples=[
            [
                "550e8400-e29b-41d4-a716-446655440002",
                "550e8400-e29b-41d4-a716-446655440004",
            ]
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "feed_ids": [
                        "550e8400-e29b-41d4-a716-446655440002",
                        "550e8400-e29b-41d4-a716-446655440004",
                    ]
                }
            ]
        }
    )


class SetMarketplaceFeedsResponse(BaseModel):
    """Response model for setting marketplace feeds."""

    updated_count: int = Field(examples=[2, 0, 5])

    model_config = ConfigDict(json_schema_extra={"examples": [{"updated_count": 2}]})
