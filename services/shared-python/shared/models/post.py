"""Post models for API responses."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .media import MediaObject, PhotoMediaObject


class SourceData(BaseModel):
    """Model for post source data."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    post_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    source_url: str = Field(
        examples=["https://t.me/techcrunch/12345", "https://rss.example.com/feed"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "created_at": "2024-01-15T10:30:00Z",
                    "post_id": "550e8400-e29b-41d4-a716-446655440002",
                    "source_url": "https://t.me/techcrunch/12345",
                }
            ]
        }
    )


class PostResponse(BaseModel):
    """Response model for single post with sources."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440003"])
    full_text: str = Field(
        examples=[
            "OpenAI has announced GPT-5 with significant improvements in reasoning..."
        ]
    )
    summary: str | None = Field(
        default=None,
        examples=["GPT-5 announcement with new reasoning capabilities", None],
    )
    image_url: str | None = Field(
        default=None,
        examples=["https://storage.example.com/posts/gpt5-banner.jpg", None],
    )
    title: str | None = Field(default=None, examples=["GPT-5 Released", None])
    media_objects: list[MediaObject] = Field(
        default_factory=list,
        examples=[
            [{"url": "https://storage.example.com/image.jpg", "type": "photo"}],
            [],
        ],
    )
    sources: list[SourceData] = Field(
        default_factory=list,
        examples=[
            [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "created_at": "2024-01-15T10:30:00Z",
                    "post_id": "550e8400-e29b-41d4-a716-446655440002",
                    "source_url": "https://t.me/openai/999",
                }
            ],
            [],
        ],
    )
    moderation_action: str | None = Field(
        default=None,
        examples=["label", "block", None],
        description="Moderation action: 'label' for marking, 'block' for hiding, None for clean posts",
    )
    moderation_labels: list[str] = Field(
        default_factory=list,
        examples=[["foreign_agent"], ["extremist_organization"], []],
        description="Moderation labels: foreign_agent, extremist_organization, terrorism",
    )
    moderation_matched_entities: list[str] = Field(
        default_factory=list,
        examples=[["Алексей Навальный"], ["ФБК"], []],
        description="Entity names that triggered moderation",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440002",
                    "created_at": "2024-01-15T10:30:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440003",
                    "full_text": "OpenAI has announced GPT-5 with significant improvements in reasoning and multimodal capabilities...",
                    "summary": "GPT-5 announcement with new reasoning capabilities",
                    "image_url": "https://storage.example.com/posts/gpt5-banner.jpg",
                    "title": "GPT-5 Released",
                    "media_objects": [
                        {
                            "url": "https://storage.example.com/image.jpg",
                            "type": "photo",
                            "width": 1200,
                            "height": 800,
                        }
                    ],
                    "sources": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440001",
                            "created_at": "2024-01-15T10:30:00Z",
                            "post_id": "550e8400-e29b-41d4-a716-446655440002",
                            "source_url": "https://t.me/openai/999",
                        }
                    ],
                    "moderation_action": None,
                    "moderation_labels": [],
                    "moderation_matched_entities": [],
                },
                {
                    "id": "550e8400-e29b-41d4-a716-446655440012",
                    "created_at": "2024-01-15T11:00:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440003",
                    "full_text": "Данное сообщение создано и (или) распространено Алексеем Навальным*, выполняющим функции иностранного агента...",
                    "summary": "Новости от иноагента",
                    "image_url": None,
                    "title": "Пост от иноагента*",
                    "media_objects": [],
                    "sources": [],
                    "moderation_action": "label",
                    "moderation_labels": ["foreign_agent"],
                    "moderation_matched_entities": ["Алексей Навальный"],
                },
                {
                    "id": "550e8400-e29b-41d4-a716-446655440014",
                    "created_at": "2024-01-15T12:00:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440003",
                    "full_text": "Материал распространён экстремистской организацией ФБК*, деятельность которой запрещена на территории РФ...",
                    "summary": "Публикация экстремистской организации",
                    "image_url": None,
                    "title": "Материал экстремистской организации",
                    "media_objects": [],
                    "sources": [],
                    "moderation_action": "label",
                    "moderation_labels": ["extremist_organization"],
                    "moderation_matched_entities": ["ФБК"],
                },
            ]
        }
    )


class PostViewsV2(BaseModel):
    """Views structure for v2 API."""

    ai_generation: str | None = Field(
        default=None,
        examples=["GPT-5 introduces breakthrough reasoning capabilities", None],
    )
    full_text: str | None = Field(
        default=None,
        examples=["OpenAI has announced GPT-5 with significant improvements...", None],
    )
    overview: str | None = Field(
        default=None, examples=["Major AI release from OpenAI", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "ai_generation": "GPT-5 introduces breakthrough reasoning capabilities",
                    "full_text": "OpenAI has announced GPT-5 with significant improvements...",
                    "overview": "Major AI release from OpenAI",
                }
            ]
        }
    )


class PostResponseV2(BaseModel):
    """v2 API response with views."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440004"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440005"])
    views: PostViewsV2 = Field(
        examples=[
            {
                "ai_generation": "GPT-5 breakthrough",
                "full_text": "OpenAI announced...",
                "overview": "Major AI release",
            }
        ]
    )
    image_url: str | None = Field(
        default=None, examples=["https://storage.example.com/posts/gpt5.jpg", None]
    )
    title: str | None = Field(default=None, examples=["GPT-5 Released", None])
    media_objects: list[MediaObject] = Field(
        default_factory=list,
        examples=[
            [{"url": "https://storage.example.com/video.mp4", "type": "video"}],
            [],
        ],
    )
    sources: list[SourceData] = Field(
        default_factory=list,
        examples=[
            [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440006",
                    "created_at": "2024-01-15T10:30:00Z",
                    "post_id": "550e8400-e29b-41d4-a716-446655440004",
                    "source_url": "https://t.me/openai/1000",
                }
            ],
            [],
        ],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440004",
                    "created_at": "2024-01-15T10:30:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440005",
                    "views": {
                        "ai_generation": "GPT-5 breakthrough announcement",
                        "full_text": "OpenAI has announced GPT-5...",
                        "overview": "Major AI release",
                    },
                    "image_url": "https://storage.example.com/posts/gpt5.jpg",
                    "title": "GPT-5 Released",
                    "media_objects": [
                        {
                            "url": "https://storage.example.com/video.mp4",
                            "type": "video",
                        }
                    ],
                    "sources": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440006",
                            "created_at": "2024-01-15T10:30:00Z",
                            "post_id": "550e8400-e29b-41d4-a716-446655440004",
                            "source_url": "https://t.me/openai/1000",
                        }
                    ],
                }
            ]
        }
    )


class PostDataV2(BaseModel):
    """Model for post data with views in feed response (v2)."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440009"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440010"])
    views: dict = Field(
        examples=[
            {"summary": "AI model release", "full_text": "OpenAI announced GPT-5..."}
        ]
    )
    media_objects: list[MediaObject] = Field(
        default_factory=list,
        examples=[
            [{"url": "https://storage.example.com/image.jpg", "type": "photo"}],
            [],
        ],
    )
    title: str | None = Field(default=None, examples=["GPT-5 Release", None])
    sources: list[SourceData] = Field(
        default_factory=list,
        examples=[
            [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440011",
                    "created_at": "2024-01-15T10:30:00Z",
                    "post_id": "550e8400-e29b-41d4-a716-446655440009",
                    "source_url": "https://t.me/openai/999",
                }
            ],
            [],
        ],
    )
    seen: bool = Field(default=False, examples=[False, True])
    moderation_action: str | None = Field(
        default=None,
        examples=["label", "block", None],
        description="Moderation action: 'label' for marking, 'block' for hiding, None for clean posts",
    )
    moderation_labels: list[str] = Field(
        default_factory=list,
        examples=[["foreign_agent"], ["extremist_organization"], []],
        description="Moderation labels: foreign_agent, extremist_organization, terrorism",
    )
    moderation_matched_entities: list[str] = Field(
        default_factory=list,
        examples=[["Алексей Навальный"], ["ФБК"], []],
        description="Entity names that triggered moderation",
    )

    @field_validator("media_objects", mode="before")
    @classmethod
    def convert_legacy_media_urls(cls, v: Any) -> list[Any]:
        """Convert legacy string URLs to PhotoMediaObject format."""
        if not v:
            return []

        result = []
        for item in v:
            if isinstance(item, str):
                url_lower = item.lower()
                mime_type = "image/jpeg"
                if url_lower.endswith(".png"):
                    mime_type = "image/png"
                elif url_lower.endswith(".gif"):
                    mime_type = "image/gif"
                elif url_lower.endswith(".webp"):
                    mime_type = "image/webp"

                result.append(
                    PhotoMediaObject(type="photo", url=item, mime_type=mime_type)
                )
            else:
                result.append(item)
        return result

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440009",
                    "created_at": "2024-01-15T10:30:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                    "views": {
                        "summary": "AI model release announcement",
                        "full_text": "OpenAI announced GPT-5...",
                        "eli5": "A smart robot got smarter",
                    },
                    "media_objects": [
                        {
                            "url": "https://storage.example.com/image.jpg",
                            "type": "photo",
                        }
                    ],
                    "title": "GPT-5 Release",
                    "sources": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440011",
                            "created_at": "2024-01-15T10:30:00Z",
                            "post_id": "550e8400-e29b-41d4-a716-446655440009",
                            "source_url": "https://t.me/openai/999",
                        }
                    ],
                    "seen": False,
                    "moderation_action": None,
                    "moderation_labels": [],
                    "moderation_matched_entities": [],
                },
                {
                    "id": "550e8400-e29b-41d4-a716-446655440012",
                    "created_at": "2024-01-15T11:00:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                    "views": {
                        "summary": "Новости от иноагента",
                        "full_text": "Данное сообщение создано и (или) распространено Алексеем Навальным*...",
                    },
                    "media_objects": [],
                    "title": "Пост от иноагента*",
                    "sources": [],
                    "seen": False,
                    "moderation_action": "label",
                    "moderation_labels": ["foreign_agent"],
                    "moderation_matched_entities": ["Алексей Навальный"],
                },
                {
                    "id": "550e8400-e29b-41d4-a716-446655440014",
                    "created_at": "2024-01-15T12:00:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                    "views": {
                        "summary": "Публикация экстремистской организации",
                        "full_text": "Материал распространён экстремистской организацией ФБК*...",
                    },
                    "media_objects": [],
                    "title": "Материал экстремистской организации",
                    "sources": [],
                    "seen": False,
                    "moderation_action": "label",
                    "moderation_labels": ["extremist_organization"],
                    "moderation_matched_entities": ["ФБК"],
                },
            ]
        }
    )


class PaginatedPostsResponse(BaseModel):
    """Paginated response for posts.

    Note: Posts with moderation_action='block' (e.g., terrorism) are filtered out
    and will not appear in the response.
    """

    posts: list[PostDataV2] = Field(
        examples=[
            [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440009",
                    "created_at": "2024-01-15T10:30:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                    "views": {"summary": "AI updates"},
                    "media_objects": [],
                    "title": "GPT-5",
                    "sources": [],
                    "seen": False,
                }
            ]
        ]
    )
    next_cursor: str | None = Field(
        default=None,
        examples=["eyJjcmVhdGVkX2F0IjogIjIwMjQtMDEtMTVUMTA6MzA6MDBaIn0=", None],
    )
    has_more: bool = Field(examples=[True, False])
    total_count: int = Field(examples=[100, 42, 0])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "posts": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440009",
                            "created_at": "2024-01-15T10:30:00Z",
                            "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                            "views": {"summary": "AI updates"},
                            "media_objects": [],
                            "title": "GPT-5",
                            "sources": [],
                            "seen": False,
                            "moderation_action": None,
                            "moderation_labels": [],
                            "moderation_matched_entities": [],
                        },
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440012",
                            "created_at": "2024-01-15T11:00:00Z",
                            "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                            "views": {"summary": "Новости от иноагента"},
                            "media_objects": [],
                            "title": "Пост от иноагента*",
                            "sources": [],
                            "seen": False,
                            "moderation_action": "label",
                            "moderation_labels": ["foreign_agent"],
                            "moderation_matched_entities": ["Алексей Навальный"],
                        },
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440014",
                            "created_at": "2024-01-15T12:00:00Z",
                            "feed_id": "550e8400-e29b-41d4-a716-446655440010",
                            "views": {"summary": "Материал экстремистской организации"},
                            "media_objects": [],
                            "title": "Материал экстремистской организации",
                            "sources": [],
                            "seen": False,
                            "moderation_action": "label",
                            "moderation_labels": ["extremist_organization"],
                            "moderation_matched_entities": ["ФБК"],
                        },
                    ],
                    "next_cursor": "eyJjcmVhdGVkX2F0IjogIjIwMjQtMDEtMTVUMTA6MzA6MDBaIiwgImlkIjogIjU1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwOSJ9",
                    "has_more": True,
                    "total_count": 100,
                }
            ]
        }
    )
