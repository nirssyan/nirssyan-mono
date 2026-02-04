"""Pydantic models for GlitchTip webhook payloads.

GlitchTip uses Slack-compatible webhook format with attachments.
"""

from pydantic import BaseModel, Field


class GlitchTipField(BaseModel):
    """Field in GlitchTip attachment (Slack-compatible format)."""

    title: str = Field(description="Field title (e.g., 'Project', 'Environment')")
    value: str = Field(description="Field value")
    short: bool = Field(default=True, description="Whether field is short")


class GlitchTipAttachment(BaseModel):
    """Attachment in GlitchTip webhook (Slack-compatible format)."""

    title: str = Field(description="Error title")
    title_link: str | None = Field(
        default=None, description="Link to error in GlitchTip"
    )
    text: str | None = Field(default=None, description="Error details (location)")
    color: str | None = Field(default=None, description="Color code (e.g., '#dc3545')")
    fields: list[GlitchTipField] = Field(
        default_factory=list,
        description="Additional fields (Project, Environment, Release)",
    )


class GlitchTipWebhookPayload(BaseModel):
    """GlitchTip webhook payload (Slack-compatible format)."""

    alias: str | None = Field(
        default=None, description="Alert alias (e.g., 'GlitchTip')"
    )
    text: str | None = Field(default=None, description="Alert text")
    attachments: list[GlitchTipAttachment] = Field(
        default_factory=list, description="Alert attachments with error details"
    )


class GlitchTipWebhookResponse(BaseModel):
    """Response to GlitchTip webhook."""

    success: bool = Field(description="Whether webhook was processed successfully")
    message: str | None = Field(default=None, description="Optional message")


class GlitchTipWebhookProcessingResult(BaseModel):
    """Internal result of webhook processing."""

    success: bool
    error_title: str | None = None
    telegram_sent: bool = False
    error_message: str | None = None
