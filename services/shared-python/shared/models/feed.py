from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from shared.enums import FeedType, RawType, SourceType

from .common import LocalizedName
from .media import MediaObject


class SourceInfo(BaseModel):
    """Source information with URL for editing."""

    en: str = Field(description="English name")
    ru: str = Field(description="Russian name")
    url: str = Field(description="Source URL (t.me/channel or RSS feed URL)")
    type: str = Field(description="Source type: TELEGRAM or RSS")


class FeedRequest(BaseModel):
    name: str = Field(examples=["Tech News", "AI Daily"])
    type: SourceType = Field(examples=["TELEGRAM", "RSS"])

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"name": "Tech News", "type": "TELEGRAM"}]}
    )


class FeedResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440000"])
    name: str = Field(examples=["Tech News", "AI Daily"])
    type: SourceType = Field(examples=["TELEGRAM", "RSS"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    is_creating_finished: bool | None = Field(
        default=None, examples=[True, False, None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "name": "Tech News",
                    "type": "TELEGRAM",
                    "created_at": "2024-01-15T10:30:00Z",
                    "is_creating_finished": True,
                }
            ]
        }
    )


class RawFeedRequest(BaseModel):
    name: str = Field(examples=["TechCrunch", "Hacker News"])
    raw_type: RawType = Field(examples=["RSS", "TELEGRAM"])
    feed_url: str = Field(examples=["https://techcrunch.com/feed/"])
    site_url: str | None = Field(
        default=None, examples=["https://techcrunch.com", None]
    )
    image_url: str | None = Field(
        default=None, examples=["https://techcrunch.com/logo.png", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "name": "TechCrunch",
                    "raw_type": "RSS",
                    "feed_url": "https://techcrunch.com/feed/",
                    "site_url": "https://techcrunch.com",
                    "image_url": "https://techcrunch.com/logo.png",
                }
            ]
        }
    )


class RawFeedResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    name: str = Field(examples=["TechCrunch", "Hacker News"])
    raw_type: RawType = Field(examples=["RSS", "TELEGRAM"])
    feed_url: str = Field(examples=["https://techcrunch.com/feed/"])
    site_url: str | None = Field(examples=["https://techcrunch.com", None])
    image_url: str | None = Field(examples=["https://techcrunch.com/logo.png", None])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "name": "TechCrunch",
                    "raw_type": "RSS",
                    "feed_url": "https://techcrunch.com/feed/",
                    "site_url": "https://techcrunch.com",
                    "image_url": "https://techcrunch.com/logo.png",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class CreateFeedRequest(BaseModel):
    """Request model for creating a feed."""

    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"chat_id": "550e8400-e29b-41d4-a716-446655440002"}]
        }
    )


class CreateFeedResponse(BaseModel):
    """Response model for feed creation."""

    success: bool = Field(examples=[True, False])
    feed_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440003", None]
    )
    message: str = Field(
        examples=["Feed created successfully", "Failed to create feed"]
    )
    is_creating_finished: bool = Field(default=False, examples=[True, False])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "feed_id": "550e8400-e29b-41d4-a716-446655440003",
                    "message": "Feed created successfully",
                    "is_creating_finished": True,
                }
            ]
        }
    )


class FeedCreationData(BaseModel):
    """Internal model for feed creation process."""

    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440003"])
    prompt: str = Field(examples=["Filter AI news only"])
    pre_prompt_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440004"])
    feed_type: str | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )


class RenameFeedRequest(BaseModel):
    """Request model for renaming a feed."""

    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440004"])
    new_name: str = Field(examples=["AI & ML Updates", "Tech News Daily"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "feed_id": "550e8400-e29b-41d4-a716-446655440004",
                    "new_name": "AI & ML Updates",
                }
            ]
        }
    )


class RenameFeedResponse(BaseModel):
    """Response model for feed rename operation."""

    success: bool = Field(examples=[True, False])
    message: str = Field(examples=["Feed renamed successfully", "Feed not found"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"success": True, "message": "Feed renamed successfully"}]
        }
    )


class ReadAllPostsResponse(BaseModel):
    """Response model for read all posts operation."""

    success: bool = Field(examples=[True, False])
    marked_count: int = Field(examples=[15, 0, 100])
    message: str = Field(examples=["15 posts marked as read", "No posts to mark"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "marked_count": 15,
                    "message": "15 posts marked as read",
                }
            ]
        }
    )


class SourceData(BaseModel):
    """Model for source data in feed response."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440005"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    post_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440006"])
    source_url: str = Field(
        examples=[
            "https://t.me/techcrunch/12345",
            "https://news.ycombinator.com/item?id=123",
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440005",
                    "created_at": "2024-01-15T10:30:00Z",
                    "post_id": "550e8400-e29b-41d4-a716-446655440006",
                    "source_url": "https://t.me/techcrunch/12345",
                }
            ]
        }
    )


class PostData(BaseModel):
    """Model for post data with sources in feed response."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440006"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440007"])
    full_text: str = Field(
        examples=["OpenAI announced GPT-5 with significant improvements..."]
    )
    summary: str | None = Field(
        default=None,
        examples=["GPT-5 release announcement with new capabilities", None],
    )
    media_objects: list[MediaObject] = Field(
        default_factory=list,
        examples=[[{"url": "https://storage.example.com/image.jpg", "type": "photo"}]],
    )
    title: str | None = Field(default=None, examples=["GPT-5 Announcement", None])
    sources: list[SourceData] = Field(default_factory=list, examples=[[]])
    seen: bool = Field(default=False, examples=[True, False])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440006",
                    "created_at": "2024-01-15T10:30:00Z",
                    "feed_id": "550e8400-e29b-41d4-a716-446655440007",
                    "full_text": "OpenAI announced GPT-5 with significant improvements...",
                    "summary": "GPT-5 release announcement with new capabilities",
                    "media_objects": [
                        {
                            "url": "https://storage.example.com/image.jpg",
                            "type": "photo",
                            "width": 1200,
                            "height": 800,
                        }
                    ],
                    "title": "GPT-5 Announcement",
                    "sources": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440008",
                            "created_at": "2024-01-15T10:30:00Z",
                            "post_id": "550e8400-e29b-41d4-a716-446655440006",
                            "source_url": "https://t.me/openai/999",
                        }
                    ],
                    "seen": False,
                }
            ]
        }
    )


class FeedMetadataResponse(BaseModel):
    """Feed metadata without embedded posts, includes unread count."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440010"])
    name: str = Field(examples=["AI Daily Digest", "Tech News"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    tags: list[str] | None = Field(default=None, examples=[["AI", "Tech"], None])
    is_creating_finished: bool | None = Field(
        default=None, examples=[True, False, None]
    )
    type: FeedType | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    unread_count: int = Field(examples=[5, 0, 42])
    posts_count: int = Field(examples=[100, 0, 500])
    raw_posts_processed: int = Field(examples=[250, 0, 1000])
    raw_feeds_count: int = Field(examples=[3, 1, 10])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440010",
                    "name": "AI Daily Digest",
                    "created_at": "2024-01-15T10:30:00Z",
                    "tags": ["AI", "Tech"],
                    "is_creating_finished": True,
                    "type": "DIGEST",
                    "unread_count": 5,
                    "posts_count": 100,
                    "raw_posts_processed": 250,
                    "raw_feeds_count": 3,
                }
            ]
        }
    )


class FeedOwnerResponse(BaseModel):
    """Owner information for feed view."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440012"])
    name: str = Field(examples=["John Doe", "user@example.com"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440012",
                    "name": "John Doe",
                }
            ]
        }
    )


class FeedViewResponse(BaseModel):
    """Detailed feed information including description and owner.

    Used for both existing feeds and preview of feeds being created from chat.
    For preview mode (from chat), id and created_at will be None.
    """

    id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440013", None]
    )
    name: str = Field(examples=["AI Research Updates", "Tech Daily"])
    description: str = Field(examples=["Latest AI research papers and announcements"])
    created_at: datetime | None = Field(
        default=None, examples=["2024-01-15T10:30:00Z", None]
    )
    type: str | None = Field(default=None, examples=["SINGLE_POST", "DIGEST", None])
    owner: FeedOwnerResponse
    prompt: str | None = Field(
        default=None, examples=["Focus on machine learning papers", None]
    )
    sources: list[SourceInfo] | None = Field(
        default=None,
        examples=[
            [
                {
                    "en": "TechCrunch",
                    "ru": "TechCrunch",
                    "url": "https://t.me/techcrunch",
                    "type": "TELEGRAM",
                }
            ],
            None,
        ],
    )
    digest_interval_hours: int | None = Field(default=None, examples=[24, 12, None])
    views: list[LocalizedName] | None = Field(
        default=None,
        examples=[[{"en": "summary", "ru": "сводка"}], None],
    )
    filters: list[LocalizedName] | None = Field(
        default=None,
        examples=[[{"en": "no_ads", "ru": "без_рекламы"}], None],
    )
    filter_ads: bool | None = Field(default=None, examples=[True, False, None])
    filter_duplicates: bool | None = Field(default=None, examples=[True, False, None])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440013",
                    "name": "AI Research Updates",
                    "description": "Latest AI research papers and announcements",
                    "created_at": "2024-01-15T10:30:00Z",
                    "type": "DIGEST",
                    "owner": {
                        "id": "550e8400-e29b-41d4-a716-446655440012",
                        "name": "John Doe",
                    },
                    "prompt": "Focus on machine learning papers",
                    "sources": [
                        {"en": "ArXiv ML", "ru": "ArXiv ML"},
                        {"en": "DeepMind Blog", "ru": "Блог DeepMind"},
                    ],
                    "digest_interval_hours": 24,
                    "views": [
                        {"en": "summary", "ru": "сводка"},
                        {"en": "key_findings", "ru": "ключевые_выводы"},
                    ],
                    "filters": [
                        {"en": "academic_only", "ru": "только_академические"},
                    ],
                    "filter_ads": True,
                    "filter_duplicates": True,
                }
            ]
        }
    )


class GenerateTitleResponse(BaseModel):
    """Response for generate_title endpoint."""

    title: str = Field(
        description="Generated 1-2 word title for the feed",
        max_length=30,
        examples=["AI News", "Tech Daily", "ML Updates"],
    )

    model_config = ConfigDict(json_schema_extra={"examples": [{"title": "AI News"}]})


class SourceInput(BaseModel):
    """Input model for a feed source."""

    url: str = Field(
        description="RSS URL or Telegram channel (@username or t.me/channel)",
        examples=["@techcrunch", "https://news.ycombinator.com/rss"],
    )
    type: RawType = Field(
        description="Source type: RSS, TELEGRAM, or WEBSITE (auto-select best method)",
        examples=["TELEGRAM", "RSS", "WEBSITE"],
    )
    detected_source_type: str | None = Field(
        default=None,
        description="Detected source type after validation (RSS_FEEDPARSER, HTML). "
        "Set automatically during feed creation.",
    )
    detected_feed_url: str | None = Field(
        default=None,
        description="Detected feed URL (e.g., RSS feed URL found for a website). "
        "Set automatically during feed creation.",
    )

    @field_validator("type")
    @classmethod
    def validate_type_matches_url(cls, v: RawType, info) -> RawType:
        """Validate that source type matches URL pattern."""
        url = info.data.get("url", "")
        is_telegram = url.startswith("@") or "t.me/" in url

        if is_telegram and v != RawType.TELEGRAM:
            raise ValueError(
                f"Source '{url}' looks like Telegram channel, but type is {v}. "
                "Use type=TELEGRAM for @username or t.me/channel URLs."
            )
        if not is_telegram and v == RawType.TELEGRAM:
            raise ValueError(
                f"Source '{url}' is not in Telegram format (@username or t.me/channel), "
                "but type is TELEGRAM. Use type=RSS for HTTP URLs."
            )

        return v

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"url": "@techcrunch", "type": "TELEGRAM"}]}
    )


class GenerateTitleRequest(BaseModel):
    """Request model for generating feed title based on configuration and sample posts."""

    sources: list[SourceInput] = Field(
        description="List of sources (RSS URLs or Telegram channels)",
        min_length=1,
        examples=[[{"url": "@techcrunch", "type": "TELEGRAM"}]],
    )
    feed_type: FeedType = Field(
        description="Feed processing type: SINGLE_POST or DIGEST",
        examples=["SINGLE_POST", "DIGEST"],
    )
    raw_prompt: str | None = Field(
        default=None,
        description="User prompt for feed processing",
        examples=["Focus on AI and machine learning news", None],
    )
    views_raw: list[str] | None = Field(
        default=None,
        description="User-defined view descriptions",
        examples=[["summary", "explain like I'm 5"], None],
    )
    filters_raw: list[str] | None = Field(
        default=None,
        description="User-defined filter descriptions",
        examples=[["no cryptocurrency", "only AI related"], None],
    )
    digest_interval_hours: int | None = Field(
        default=None,
        description="Hours between digest generation (1-48). Only for DIGEST type.",
        ge=1,
        le=48,
        examples=[24, 12, None],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "sources": [
                        {"url": "@techcrunch", "type": "TELEGRAM"},
                        {"url": "https://news.ycombinator.com/rss", "type": "RSS"},
                    ],
                    "feed_type": "SINGLE_POST",
                    "raw_prompt": "Focus on AI and machine learning news",
                    "views_raw": ["summary", "explain like I'm 5"],
                    "filters_raw": ["no cryptocurrency", "only AI related"],
                    "digest_interval_hours": None,
                }
            ]
        }
    )


class CreateFeedFullRequest(BaseModel):
    """Request model for creating a feed with all fields directly."""

    name: str | None = Field(
        default=None,
        description="Feed name (auto-generated if not provided)",
        max_length=100,
        examples=["AI Daily", "Tech News", None],
    )
    description: str | None = Field(
        default=None,
        description="Feed description",
        examples=["Daily AI news and research updates", None],
    )
    tags: list[str] | None = Field(
        default=None,
        description="1-4 tags for the feed",
        max_length=4,
        examples=[["AI", "Tech", "Research"], None],
    )
    sources: list[SourceInput] = Field(
        description="List of sources (RSS URLs or Telegram channels)",
        min_length=1,
        examples=[[{"url": "@openai", "type": "TELEGRAM"}]],
    )
    feed_type: FeedType = Field(
        description="Feed processing type: SINGLE_POST or DIGEST",
        examples=["SINGLE_POST", "DIGEST"],
    )
    raw_prompt: str | None = Field(
        default=None,
        description="User prompt for feed processing (e.g., 'show only AI-related posts')",
        examples=["Focus on breakthrough announcements", None],
    )
    views_raw: list[str] | None = Field(
        default=None,
        description="User-defined view descriptions (e.g., ['explain like I'm 5'])",
        examples=[["summary", "implications"], None],
    )
    filters_raw: list[str] | None = Field(
        default=None,
        description="User-defined filter descriptions (e.g., ['no ads', 'only AI'])",
        examples=[["no job postings"], None],
    )
    digest_interval_hours: int | None = Field(
        default=None,
        description="Hours between digest generation (1-48). Only for DIGEST type.",
        ge=1,
        le=48,
        examples=[24, 12, None],
    )

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, v: list[str] | None) -> list[str] | None:
        if v is not None and len(v) > 4:
            raise ValueError("Maximum 4 tags allowed")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "name": "AI Daily",
                    "description": "Daily AI news and research updates",
                    "tags": ["AI", "Tech", "Research"],
                    "sources": [
                        {"url": "@openai", "type": "TELEGRAM"},
                        {"url": "@deepmind", "type": "TELEGRAM"},
                    ],
                    "feed_type": "DIGEST",
                    "raw_prompt": "Focus on breakthrough announcements",
                    "views_raw": ["summary", "implications"],
                    "filters_raw": ["no job postings"],
                    "digest_interval_hours": 24,
                }
            ]
        }
    )


class CreateFeedFullResponse(BaseModel):
    """Response model for feed creation."""

    success: bool = Field(examples=[True, False])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440014"])
    prompt_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440015"])
    message: str = Field(
        examples=["Feed 'AI Daily' created successfully", "Failed to create feed"]
    )
    is_creating_finished: bool = Field(default=False, examples=[True, False])
    source_types: dict[str, str] | None = Field(
        default=None,
        description="Detected source types for each URL (e.g. RSS_FEEDPARSER, HTML, TELEGRAM)",
        examples=[{"https://example.com/rss": "RSS_FEEDPARSER"}],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "feed_id": "550e8400-e29b-41d4-a716-446655440014",
                    "prompt_id": "550e8400-e29b-41d4-a716-446655440015",
                    "message": "Feed 'AI Daily' created successfully",
                    "is_creating_finished": False,
                    "source_types": {"https://example.com/rss": "RSS_FEEDPARSER"},
                }
            ]
        }
    )


class UpdateFeedRequest(BaseModel):
    """Request model for updating feed settings."""

    name: str | None = Field(
        default=None,
        description="New feed name",
        max_length=100,
        examples=["AI Daily Updated", None],
    )
    description: str | None = Field(
        default=None,
        description="New feed description",
        examples=["Updated description for the feed", None],
    )
    tags: list[str] | None = Field(
        default=None,
        description="1-4 tags for the feed",
        max_length=4,
        examples=[["AI", "Tech"], None],
    )
    sources: list[SourceInput] | None = Field(
        default=None,
        description="New list of sources (replaces all existing sources)",
        min_length=1,
        examples=[[{"url": "@openai", "type": "TELEGRAM"}], None],
    )
    raw_prompt: str | None = Field(
        default=None,
        description="User prompt for feed processing",
        examples=["Focus on AI breakthroughs", None],
    )
    views_raw: list[str] | None = Field(
        default=None,
        description="User-defined view descriptions",
        examples=[["summary", "implications"], None],
    )
    filters_raw: list[str] | None = Field(
        default=None,
        description="User-defined filter descriptions",
        examples=[["no ads"], None],
    )
    digest_interval_hours: int | None = Field(
        default=None,
        description="Hours between digest generation (1-48). Only for DIGEST type.",
        ge=1,
        le=48,
        examples=[24, 12, None],
    )

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, v: list[str] | None) -> list[str] | None:
        if v is not None and len(v) > 4:
            raise ValueError("Maximum 4 tags allowed")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "name": "AI Daily Updated",
                    "tags": ["AI", "Tech"],
                },
                {
                    "sources": [
                        {"url": "@openai", "type": "TELEGRAM"},
                        {"url": "@deepmind", "type": "TELEGRAM"},
                    ],
                    "raw_prompt": "Focus on breakthrough announcements",
                },
            ]
        }
    )


class UpdateFeedResponse(BaseModel):
    """Response model for feed update."""

    success: bool = Field(examples=[True, False])
    feed_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440014"])
    message: str = Field(
        examples=["Feed updated successfully", "Failed to update feed"]
    )
    updated_fields: list[str] = Field(
        description="List of fields that were updated",
        examples=[["name", "tags"], ["sources", "raw_prompt"]],
    )
    source_types: dict[str, str] | None = Field(
        default=None,
        description="Detected source types for new sources (if sources were updated)",
        examples=[{"@openai": "TELEGRAM", "https://example.com/rss": "RSS_FEEDPARSER"}],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "feed_id": "550e8400-e29b-41d4-a716-446655440014",
                    "message": "Feed updated successfully",
                    "updated_fields": ["name", "tags"],
                    "source_types": None,
                }
            ]
        }
    )
