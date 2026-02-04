"""Pydantic models for Sentry webhook payloads."""

from typing import Any

from pydantic import BaseModel, Field


class SentryProject(BaseModel):
    """Sentry project information."""

    id: str = Field(description="Project ID")
    name: str = Field(description="Project name")
    slug: str = Field(description="Project slug")
    platform: str | None = Field(default=None, description="Project platform")


class SentryIssueMetadata(BaseModel):
    """Issue metadata containing error type details."""

    type: str | None = Field(default=None, description="Error type (e.g., TypeError)")
    value: str | None = Field(default=None, description="Error value/message")
    title: str | None = Field(default=None, description="Error title")


class SentryIssue(BaseModel):
    """Sentry issue object."""

    id: str = Field(description="Issue ID")
    shortId: str = Field(description="Short issue ID (e.g., PROJECT-123)")
    title: str = Field(description="Issue title")
    culprit: str | None = Field(
        default=None, description="Culprit (e.g., module.function)"
    )
    level: str = Field(default="error", description="Severity level")
    status: str = Field(description="Issue status")
    substatus: str | None = Field(default=None, description="Issue substatus")
    platform: str | None = Field(default=None, description="Platform")
    project: SentryProject = Field(description="Project info")
    metadata: SentryIssueMetadata | None = Field(
        default=None, description="Error metadata"
    )
    count: str | None = Field(default=None, description="Event count")
    userCount: int | None = Field(default=None, description="Affected users count")
    firstSeen: str | None = Field(default=None, description="First seen timestamp")
    lastSeen: str | None = Field(default=None, description="Last seen timestamp")
    permalink: str | None = Field(default=None, description="Permalink to issue")
    web_url: str | None = Field(default=None, description="Web URL for issue")
    priority: str | None = Field(default=None, description="Issue priority")
    issueType: str | None = Field(default=None, description="Issue type")
    issueCategory: str | None = Field(default=None, description="Issue category")
    assignedTo: dict[str, Any] | None = Field(default=None, description="Assignee info")


class SentryActor(BaseModel):
    """Actor who performed the action."""

    type: str = Field(description="Actor type (user/application)")
    id: int | str | None = Field(default=None, description="Actor ID")
    name: str | None = Field(default=None, description="Actor name")


class SentryInstallation(BaseModel):
    """Sentry installation info."""

    uuid: str = Field(description="Installation UUID")


class SentryWebhookData(BaseModel):
    """Sentry webhook data container."""

    issue: SentryIssue = Field(description="Issue data")


class SentryWebhookPayload(BaseModel):
    """Sentry webhook payload."""

    action: str = Field(
        description="Action type (created/resolved/assigned/archived/unresolved)"
    )
    data: SentryWebhookData = Field(description="Webhook data")
    installation: SentryInstallation | None = Field(
        default=None, description="Installation info"
    )
    actor: SentryActor | None = Field(
        default=None, description="Actor who performed action"
    )


class SentryWebhookResponse(BaseModel):
    """Response to Sentry webhook."""

    success: bool = Field(description="Whether webhook was processed successfully")
    message: str | None = Field(default=None, description="Optional message")


class SentryWebhookProcessingResult(BaseModel):
    """Internal result of webhook processing."""

    success: bool
    action: str | None = None
    issue_id: str | None = None
    telegram_sent: bool = False
    error_message: str | None = None
