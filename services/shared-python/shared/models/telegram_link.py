"""Pydantic models for Telegram account linking endpoints."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TelegramLinkUrlResponse(BaseModel):
    """Response for GET /api/telegram/link-url endpoint."""

    url: str = Field(
        ...,
        description="Telegram deep link URL with token",
        examples=["https://t.me/MakeFeedBot?start=link_abc123def456"],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"url": "https://t.me/MakeFeedBot?start=link_abc123def456"}]
        }
    )


class TelegramAccountInfo(BaseModel):
    """Telegram account information."""

    telegram_id: int = Field(examples=[123456789, 987654321])
    telegram_username: str | None = Field(default=None, examples=["johndoe", None])
    telegram_first_name: str | None = Field(
        default=None, examples=["John", "Jane", None]
    )
    linked_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "telegram_id": 123456789,
                    "telegram_username": "johndoe",
                    "telegram_first_name": "John",
                    "linked_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class TelegramStatusResponse(BaseModel):
    """Response for GET /api/telegram/status endpoint."""

    is_linked: bool = Field(
        ..., description="Whether a Telegram account is linked", examples=[True, False]
    )
    account: TelegramAccountInfo | None = Field(
        None,
        description="Linked Telegram account details (null if not linked)",
        examples=[
            {
                "telegram_id": 123456789,
                "telegram_username": "johndoe",
                "telegram_first_name": "John",
                "linked_at": "2024-01-15T10:30:00Z",
            },
            None,
        ],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "is_linked": True,
                    "account": {
                        "telegram_id": 123456789,
                        "telegram_username": "johndoe",
                        "telegram_first_name": "John",
                        "linked_at": "2024-01-15T10:30:00Z",
                    },
                }
            ]
        }
    )


class TelegramUnlinkResponse(BaseModel):
    """Response for DELETE /api/telegram/unlink endpoint."""

    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Telegram account unlinked successfully", "No linked account found"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"success": True, "message": "Telegram account unlinked successfully"}
            ]
        }
    )
