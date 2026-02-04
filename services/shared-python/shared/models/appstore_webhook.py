"""Pydantic models for App Store Connect webhook payloads."""

from typing import Any

from pydantic import BaseModel, Field


class AppStoreWebhookData(BaseModel):
    """App Store Connect webhook data object."""

    type: str = Field(
        description="Event type (e.g., appStoreVersionAppVersionStateUpdated)"
    )
    id: str = Field(description="Unique event UUID")
    version: int = Field(default=1, description="API version")
    attributes: dict[str, Any] = Field(
        default_factory=dict,
        description="Event-specific attributes (e.g., oldState, newState)",
    )
    relationships: dict[str, Any] | None = Field(
        default=None,
        description="Linked App Store Connect API resources",
    )


class AppStoreWebhookPayload(BaseModel):
    """App Store Connect webhook payload."""

    data: AppStoreWebhookData


class AppStoreWebhookResponse(BaseModel):
    """Response to App Store Connect webhook."""

    success: bool = Field(description="Whether webhook was processed successfully")
    message: str | None = Field(default=None, description="Optional message")


class AppStoreWebhookProcessingResult(BaseModel):
    """Internal result of webhook processing."""

    success: bool
    event_type: str | None = None
    telegram_sent: bool = False
    error_message: str | None = None
