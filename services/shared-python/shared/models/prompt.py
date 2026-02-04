from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from shared.enums import FeedType, PrePromptType, TriggerType


class PrePromptRequest(BaseModel):
    prompt: str | None = Field(default=None, examples=["Find AI news", None])
    sources: list[str] | None = Field(
        default=None, examples=[["@TechNews", "@AIDaily"], None]
    )
    suggestions: list[str] | None = Field(
        default=None, examples=[["Add more sources", "Set digest interval"], None]
    )
    type: PrePromptType | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    is_ready_to_create_feed: bool | None = Field(
        default=None, examples=[True, False, None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "prompt": "Find AI news",
                    "sources": ["@TechNews"],
                    "type": "SINGLE_POST",
                    "is_ready_to_create_feed": True,
                }
            ]
        }
    )


class PrePromptResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    prompt: str | None = Field(default=None, examples=["Find AI news", None])
    sources: list[str] | None = Field(
        default=None, examples=[["@TechNews", "@AIDaily"], None]
    )
    suggestions: list[str] | None = Field(
        default=None, examples=[["Add more sources"], None]
    )
    type: PrePromptType | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    is_ready_to_create_feed: bool | None = Field(
        default=None, examples=[True, False, None]
    )
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "prompt": "Find AI news",
                    "sources": ["@TechNews"],
                    "type": "SINGLE_POST",
                    "is_ready_to_create_feed": True,
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class PromptRequest(BaseModel):
    trigger_type: TriggerType | None = Field(
        default=None, examples=["CRON", "WEBHOOK", None]
    )
    prompt: str = Field(examples=["Filter posts about AI and technology"])
    cron: str | None = Field(default=None, examples=["0 9 * * *", None])
    feed_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440002", None]
    )
    raw_prompt: str = Field(default="", examples=["user's original prompt", ""])
    feed_type: FeedType | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    pre_prompt_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440003", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "trigger_type": "CRON",
                    "prompt": "Filter posts about AI",
                    "cron": "0 9 * * *",
                    "feed_type": "SINGLE_POST",
                }
            ]
        }
    )


class PromptResponse(BaseModel):
    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    trigger_type: TriggerType | None = Field(
        default=None, examples=["CRON", "WEBHOOK", None]
    )
    prompt: str = Field(examples=["Filter posts about AI and technology"])
    cron: str | None = Field(default=None, examples=["0 9 * * *", None])
    last_execution: datetime | None = Field(
        default=None, examples=["2024-01-15T09:00:00Z", None]
    )
    feed_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440002", None]
    )
    raw_prompt: str = Field(examples=["user's original prompt", ""])
    feed_type: FeedType | None = Field(
        default=None, examples=["SINGLE_POST", "DIGEST", None]
    )
    pre_prompt_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440003", None]
    )
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "trigger_type": "CRON",
                    "prompt": "Filter posts about AI",
                    "cron": "0 9 * * *",
                    "feed_type": "SINGLE_POST",
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )
