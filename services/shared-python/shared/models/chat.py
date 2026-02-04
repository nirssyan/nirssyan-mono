from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from shared.enums import MessageType


class DeleteChatRequest(BaseModel):
    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"chat_id": "550e8400-e29b-41d4-a716-446655440001"}]
        }
    )


class ChatResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    pre_prompt_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440003"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "user_id": "550e8400-e29b-41d4-a716-446655440002",
                    "pre_prompt_id": "550e8400-e29b-41d4-a716-446655440003",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class ChatMessageRequest(BaseModel):
    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    message: str = Field(examples=["I want to follow AI and machine learning news"])
    current_feed_info: dict[str, Any] | None = Field(
        default=None,
        examples=[{"title": "AI News", "sources": ["@AINewsChannel"]}, None],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                    "message": "I want to follow AI and machine learning news",
                    "current_feed_info": {
                        "title": "AI News",
                        "sources": ["@AINewsChannel"],
                        "type": "SINGLE_POST",
                    },
                }
            ]
        }
    )


class ChatMessageResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    message: str = Field(examples=["Great! I can help you set up a feed for AI news."])
    type: MessageType = Field(examples=["assistant", "user"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "chat_id": "550e8400-e29b-41d4-a716-446655440002",
                    "message": "Great! I can help you set up a feed for AI news.",
                    "type": "assistant",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class ChatMessageInList(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440002"])
    message: str = Field(examples=["Hello, I want to create a tech news feed"])
    type: MessageType = Field(examples=["user", "assistant"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "chat_id": "550e8400-e29b-41d4-a716-446655440002",
                    "message": "Hello, I want to create a tech news feed",
                    "type": "user",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class ChatWithMessagesResponse(BaseModel):
    chat_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    suggestions: list[str] | None = Field(
        default=None, examples=[["Add more sources", "Set up daily digest"], None]
    )
    is_ready_to_create_feed: bool | None = Field(
        default=None, examples=[True, False, None]
    )
    messages: list[ChatMessageInList] = Field(
        examples=[
            [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440002",
                    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                    "message": "I want AI news",
                    "type": "user",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                    "created_at": "2024-01-15T10:30:00Z",
                    "suggestions": [
                        "Add more sources",
                        "Set up daily digest",
                        "Filter by keywords",
                    ],
                    "is_ready_to_create_feed": True,
                    "messages": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440002",
                            "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                            "message": "I want AI news",
                            "type": "user",
                            "created_at": "2024-01-15T10:30:00Z",
                        },
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440003",
                            "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                            "message": "I found several AI news sources for you.",
                            "type": "assistant",
                            "created_at": "2024-01-15T10:30:05Z",
                        },
                    ],
                }
            ]
        }
    )


class ChatsListResponse(BaseModel):
    chats: list[ChatWithMessagesResponse] = Field(
        examples=[
            [
                {
                    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                    "created_at": "2024-01-15T10:30:00Z",
                    "suggestions": ["Add filters"],
                    "is_ready_to_create_feed": True,
                    "messages": [],
                }
            ]
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "chats": [
                        {
                            "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                            "created_at": "2024-01-15T10:30:00Z",
                            "suggestions": ["Add filters", "Change interval"],
                            "is_ready_to_create_feed": True,
                            "messages": [
                                {
                                    "id": "550e8400-e29b-41d4-a716-446655440002",
                                    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
                                    "message": "Create tech feed",
                                    "type": "user",
                                    "created_at": "2024-01-15T10:30:00Z",
                                }
                            ],
                        }
                    ]
                }
            ]
        }
    )


class CurrentFeedInfoResponse(BaseModel):
    prompt: str | None = Field(
        default=None,
        examples=["Show me the latest news about artificial intelligence", None],
    )
    sources: list[str] | None = Field(
        default=None, examples=[["@AINewsDaily", "@TechCrunch"], None]
    )
    source_types: dict[str, str] | None = Field(
        default=None,
        examples=[{"@AINewsDaily": "TELEGRAM", "@TechCrunch": "TELEGRAM"}, None],
    )
    type: str | None = Field(default=None, examples=["SINGLE_POST", "DIGEST", None])
    description: str | None = Field(
        default=None, examples=["Curated AI news from top sources", None]
    )
    title: str | None = Field(default=None, examples=["AI News Feed", None])
    tags: list[str] | None = Field(
        default=None, examples=[["AI", "Technology", "News"], None]
    )
    digest_interval_hours: int | None = Field(default=None, examples=[24, 12, None])
    filters: list[str] | None = Field(
        default=None, examples=[["machine learning", "neural networks"], None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "prompt": "Show me the latest news about artificial intelligence",
                    "sources": ["@AINewsDaily", "@TechCrunch"],
                    "source_types": {
                        "@AINewsDaily": "TELEGRAM",
                        "@TechCrunch": "TELEGRAM",
                    },
                    "type": "SINGLE_POST",
                    "description": "Curated AI news from top sources",
                    "title": "AI News Feed",
                    "tags": ["AI", "Technology", "News"],
                    "digest_interval_hours": None,
                    "filters": ["machine learning", "neural networks"],
                }
            ]
        }
    )


class LimitExceptionResponse(BaseModel):
    """Exception information for limit violations."""

    message: str = Field(
        description="Exception message",
        examples=[
            "You have reached the maximum number of sources (10)",
            "Feed creation limit exceeded for this month",
        ],
    )
    color: Literal["YELLOW", "RED"] = Field(
        description="Exception severity color", examples=["YELLOW", "RED"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "message": "You have reached the maximum number of sources (10)",
                    "color": "YELLOW",
                },
                {
                    "message": "Feed creation limit exceeded for this month",
                    "color": "RED",
                },
            ]
        }
    )


class CompleteChatMessageResponse(BaseModel):
    """Complete response for chat message endpoint including AI response and state."""

    response: str = Field(
        examples=["I've configured your AI news feed with 3 sources."]
    )
    current_feed_info: CurrentFeedInfoResponse = Field(
        examples=[
            {
                "prompt": "Latest AI news",
                "sources": ["@AINewsDaily"],
                "type": "SINGLE_POST",
            }
        ]
    )
    suggestions: list[str] = Field(
        examples=[["Add web sources", "Enable daily digest", "Add keyword filters"]]
    )
    is_ready_to_create_feed: bool = Field(examples=[True, False])
    exceptions: list[LimitExceptionResponse] = Field(
        default_factory=list,
        description="List of limit violations, empty if no limits exceeded",
        examples=[[], [{"message": "Maximum sources reached", "color": "YELLOW"}]],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "response": "I've configured your AI news feed with 3 sources.",
                    "current_feed_info": {
                        "prompt": "Latest AI news and research",
                        "sources": ["@AINewsDaily", "@DeepMind", "@OpenAI"],
                        "source_types": {
                            "@AINewsDaily": "TELEGRAM",
                            "@DeepMind": "TELEGRAM",
                            "@OpenAI": "TELEGRAM",
                        },
                        "type": "SINGLE_POST",
                        "description": "AI news from leading sources",
                        "title": "AI Research Updates",
                        "tags": ["AI", "Research"],
                        "digest_interval_hours": None,
                        "filters": None,
                    },
                    "suggestions": [
                        "Add web sources",
                        "Enable daily digest",
                        "Add keyword filters",
                    ],
                    "is_ready_to_create_feed": True,
                    "exceptions": [],
                }
            ]
        }
    )


class UpdateFeedPreviewRequest(BaseModel):
    """Request model for updating feed preview fields."""

    title: str | None = Field(default=None, examples=["Updated Feed Title", None])
    description: str | None = Field(
        default=None, examples=["New description for the feed", None]
    )
    tags: list[str] | None = Field(
        default=None, examples=[["Tech", "News", "AI"], None]
    )
    sources: list[str] | None = Field(
        default=None, examples=[["@TechNews", "@AIUpdates"], None]
    )
    source_types: dict[str, str] | None = Field(
        default=None,
        examples=[{"@TechNews": "TELEGRAM", "@AIUpdates": "TELEGRAM"}, None],
    )
    type: Literal["SINGLE_POST", "DIGEST"] | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    prompt: str | None = Field(
        default=None, examples=["Summarize tech news focusing on AI", None]
    )
    digest_interval_hours: int | None = Field(default=None, examples=[24, 12, None])
    filters: list[str] | None = Field(
        default=None, examples=[["artificial intelligence", "machine learning"], None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "title": "Updated Feed Title",
                    "description": "New description for the feed",
                    "tags": ["Tech", "News", "AI"],
                    "sources": ["@TechNews", "@AIUpdates"],
                    "source_types": {
                        "@TechNews": "TELEGRAM",
                        "@AIUpdates": "TELEGRAM",
                    },
                    "type": "DIGEST",
                    "prompt": "Summarize tech news focusing on AI",
                    "digest_interval_hours": 24,
                    "filters": ["artificial intelligence", "machine learning"],
                }
            ]
        }
    )


class UpdateFeedPreviewResponse(BaseModel):
    """Response model for updating feed preview."""

    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Feed preview updated successfully", "Failed to update feed preview"]
    )
    current_feed_info: CurrentFeedInfoResponse = Field(
        examples=[
            {
                "prompt": "Summarize tech news",
                "sources": ["@TechNews"],
                "type": "DIGEST",
            }
        ]
    )
    is_ready_to_create_feed: bool = Field(examples=[True, False])
    exceptions: list[str] = Field(
        default_factory=list, examples=[[], ["Source validation failed"]]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "message": "Feed preview updated successfully",
                    "current_feed_info": {
                        "prompt": "Summarize tech news",
                        "sources": ["@TechNews"],
                        "source_types": {"@TechNews": "TELEGRAM"},
                        "type": "DIGEST",
                        "description": "Daily tech digest",
                        "title": "Tech Digest",
                        "tags": ["Tech"],
                        "digest_interval_hours": 24,
                        "filters": None,
                    },
                    "is_ready_to_create_feed": True,
                    "exceptions": [],
                }
            ]
        }
    )
