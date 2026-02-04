"""Event schema for scheduled digest execution."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class DigestScheduledEvent(BaseModel):
    """Event published when a digest is scheduled for execution."""

    event_type: str = Field(default="digest.scheduled", frozen=True)
    prompt_id: UUID
    scheduled_at: datetime
    interval_hours: int = Field(ge=1, le=168)  # 1 hour to 1 week

    model_config = {"frozen": True}
