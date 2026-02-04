"""Models for summarize unseen endpoint."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from .media import MediaObject
from .post import SourceData


class SummarizeUnseenSourceInfo(BaseModel):
    """Source post info for created digest."""

    post_id: UUID
    title: str | None = None


class SummarizeUnseenPostViews(BaseModel):
    """Views structure for summarize unseen post."""

    summary: str
    full_text: str


class SummarizeUnseenResponse(BaseModel):
    """Response for POST /summarize_unseen/{feed_id}."""

    id: UUID
    created_at: datetime
    feed_id: UUID
    title: str | None = None
    views: SummarizeUnseenPostViews
    summary: str
    full_text: str
    sources_info: list[SummarizeUnseenSourceInfo]
    marked_as_seen_count: int
    media_objects: list[MediaObject] = []
    sources: list[SourceData] = []
