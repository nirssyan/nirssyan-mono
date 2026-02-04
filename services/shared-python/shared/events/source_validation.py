"""Event schemas for source validation request-reply pattern."""

from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class TelegramValidationRequest(BaseModel):
    """Request to validate a Telegram channel or folder invite.

    Sent by:
        - makefeed-api: When user adds a new Telegram source

    Handled by:
        - makefeed-telegram: Uses Pyrogram to validate
    """

    request_id: UUID = Field(default_factory=uuid4)
    url: str = Field(description="Telegram URL to validate (@channel or t.me/... link)")
    validation_type: Literal["CHANNEL", "FOLDER"] = Field(
        description="Type of validation: CHANNEL or FOLDER (invite link)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "url": "https://t.me/durov",
                "validation_type": "CHANNEL",
            }
        }
    )


class TelegramValidationResponse(BaseModel):
    """Response from Telegram validation.

    Returned by:
        - makefeed-telegram: After validating the source
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    valid: bool = Field(description="Whether the source is valid and accessible")
    source_type: Literal["TELEGRAM", "TELEGRAM_FOLDER"] | None = Field(
        default=None,
        description="Detected source type if valid",
    )
    message: str = Field(description="Human-readable status message")
    channel_title: str | None = Field(
        default=None,
        description="Channel title (for CHANNEL type)",
    )
    channel_username: str | None = Field(
        default=None,
        description="Channel username without @ (for CHANNEL type)",
    )
    channel_id: int | None = Field(
        default=None,
        description="Telegram channel ID (for CHANNEL type)",
    )
    channel_usernames: list[str] | None = Field(
        default=None,
        description="List of channel usernames (for FOLDER type)",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "valid": True,
                "source_type": "TELEGRAM",
                "message": "Channel validated successfully",
                "channel_title": "Pavel Durov",
                "channel_username": "durov",
                "channel_id": 123456789,
            }
        }
    )


class WebValidationRequest(BaseModel):
    """Request to validate a web source (RSS or website).

    Sent by:
        - makefeed-api: When user adds a new web source

    Handled by:
        - makefeed-web: Validates accessibility and detects type
    """

    request_id: UUID = Field(default_factory=uuid4)
    url: str = Field(description="Web URL to validate")
    lightweight: bool = Field(
        default=False,
        description="True for quick validation (chat), False for full validation",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "url": "https://example.com/feed.xml",
                "lightweight": False,
            }
        }
    )


class WebValidationResponse(BaseModel):
    """Response from web source validation.

    Returned by:
        - makefeed-web: After validating the source
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    valid: bool = Field(description="Whether the source is valid and accessible")
    source_type: Literal["RSS_FEEDPARSER", "HTML", "SITEMAP"] | None = Field(
        default=None,
        description="Detected source type if valid",
    )
    message: str = Field(description="Human-readable status message")
    detected_feed_url: str | None = Field(
        default=None,
        description="Actual feed URL if different from input (e.g., autodiscovered RSS)",
    )
    site_title: str | None = Field(
        default=None,
        description="Website/feed title if detected",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "valid": True,
                "source_type": "RSS_FEEDPARSER",
                "message": "RSS feed validated successfully",
                "detected_feed_url": "https://example.com/feed.xml",
                "site_title": "Example Blog",
            }
        }
    )
