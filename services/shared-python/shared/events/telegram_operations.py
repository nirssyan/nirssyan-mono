"""Event schemas for Telegram operations request-reply pattern.

These messages enable makefeed-api to communicate with makefeed-telegram
for all Telegram-related operations via NATS request-reply.
"""

import base64
from datetime import datetime
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class ChannelResolveRequest(BaseModel):
    """Request to resolve a Telegram channel info.

    Sent by:
        - makefeed-api: When creating feeds or validating channels

    Handled by:
        - makefeed-telegram: Uses Pyrogram to resolve channel
    """

    request_id: UUID = Field(default_factory=uuid4)
    url: str = Field(description="Telegram URL (@channel or t.me/... link)")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "url": "@durov",
            }
        }
    )


class ChannelResolveResponse(BaseModel):
    """Response from channel resolution.

    Returned by:
        - makefeed-telegram: After resolving the channel
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(description="Whether the channel was resolved successfully")
    chat_id: int | None = Field(default=None, description="Telegram chat ID")
    username: str | None = Field(default=None, description="Channel username without @")
    title: str | None = Field(default=None, description="Channel title")
    error: str | None = Field(default=None, description="Error message if failed")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "chat_id": -1001234567890,
                "username": "durov",
                "title": "Pavel Durov",
            }
        }
    )


class TelegramMessageData(BaseModel):
    """Telegram message data for NATS transfer.

    Mirrors TelegramMessage dataclass but as Pydantic model for serialization.
    """

    message_id: int
    title: str
    content: str
    media_objects: list[dict[str, Any]] = Field(default_factory=list)
    pub_date: datetime
    media_group_id: str | None = None


class GetMessagesRequest(BaseModel):
    """Request to get messages from a Telegram channel.

    Sent by:
        - makefeed-api: For initial sync or manual refresh

    Handled by:
        - makefeed-telegram: Fetches messages via Pyrogram
    """

    request_id: UUID = Field(default_factory=uuid4)
    channel_username: str = Field(description="Channel username without @")
    limit: int = Field(default=100, le=1000, description="Max messages to fetch")
    since_date: datetime | None = Field(
        default=None, description="Only fetch messages after this date"
    )
    min_posts_after_grouping: int | None = Field(
        default=None,
        description="Keep fetching batches until this many posts after media grouping",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "channel_username": "durov",
                "limit": 100,
                "since_date": "2024-01-01T00:00:00Z",
            }
        }
    )


class GetMessagesResponse(BaseModel):
    """Response with fetched messages.

    Returned by:
        - makefeed-telegram: After fetching messages
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(description="Whether messages were fetched successfully")
    messages: list[TelegramMessageData] = Field(default_factory=list)
    error: str | None = Field(default=None, description="Error message if failed")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "messages": [
                    {
                        "message_id": 12345,
                        "title": "Post Title",
                        "content": "Post content...",
                        "media_objects": [],
                        "pub_date": "2024-01-01T12:00:00Z",
                    }
                ],
            }
        }
    )


class RefetchMessageRequest(BaseModel):
    """Request to refetch a message for fresh file references.

    Sent by:
        - makefeed-api: When FILE_REFERENCE_EXPIRED error occurs

    Handled by:
        - makefeed-telegram: Refetches message via Pyrogram
    """

    request_id: UUID = Field(default_factory=uuid4)
    chat_id: int = Field(description="Telegram chat ID")
    message_id: int = Field(description="Message ID to refetch")
    media_type: str = Field(description="Expected media type: photo, video, document")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "chat_id": -1001234567890,
                "message_id": 12345,
                "media_type": "video",
            }
        }
    )


class RefetchMessageResponse(BaseModel):
    """Response with fresh file references.

    Returned by:
        - makefeed-telegram: After refetching message
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(description="Whether refetch was successful")
    file_id: str | None = Field(default=None, description="Fresh file ID")
    file_unique_id: str | None = Field(default=None, description="File unique ID")
    actual_media_type: str | None = Field(
        default=None, description="Actual media type found"
    )
    error: str | None = Field(default=None, description="Error message if failed")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "file_id": "CAACAgIAAxkBAAI...",
                "file_unique_id": "AgADAgAT...",
                "actual_media_type": "video",
            }
        }
    )


class DownloadMediaRequest(BaseModel):
    """Request to download media from Telegram.

    Sent by:
        - makefeed-api: When serving media to clients

    Handled by:
        - makefeed-telegram: Downloads via Pyrogram
    """

    request_id: UUID = Field(default_factory=uuid4)
    file_id: str = Field(description="Telegram file ID")
    file_unique_id: str | None = Field(
        default=None, description="File unique ID for validation"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "file_id": "CAACAgIAAxkBAAI...",
                "file_unique_id": "AgADAgAT...",
            }
        }
    )


class DownloadMediaResponse(BaseModel):
    """Response with downloaded media data.

    Returned by:
        - makefeed-telegram: After downloading media

    Note: data is base64-encoded bytes for JSON serialization.
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(description="Whether download was successful")
    data_base64: str | None = Field(
        default=None, description="Base64-encoded file data"
    )
    mime_type: str | None = Field(default=None, description="MIME type of the file")
    file_size: int | None = Field(default=None, description="File size in bytes")
    error: str | None = Field(default=None, description="Error message if failed")

    def get_data(self) -> bytes | None:
        """Decode base64 data to bytes."""
        if self.data_base64 is None:
            return None
        return base64.b64decode(self.data_base64)

    @classmethod
    def from_bytes(
        cls,
        request_id: UUID,
        data: bytes,
        mime_type: str | None = None,
    ) -> "DownloadMediaResponse":
        """Create response from raw bytes."""
        return cls(
            request_id=request_id,
            success=True,
            data_base64=base64.b64encode(data).decode("ascii"),
            mime_type=mime_type,
            file_size=len(data),
        )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "data_base64": "SGVsbG8gV29ybGQh",
                "mime_type": "video/mp4",
                "file_size": 1024000,
            }
        }
    )


class ParseFolderInviteRequest(BaseModel):
    """Request to parse a Telegram folder invite link.

    Sent by:
        - makefeed-api: When validating folder invite URLs

    Handled by:
        - makefeed-telegram: Parses folder invite via Pyrogram
    """

    request_id: UUID = Field(default_factory=uuid4)
    url: str = Field(description="Telegram folder invite URL (t.me/addlist/...)")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "url": "https://t.me/addlist/abc123",
            }
        }
    )


class ParseFolderInviteResponse(BaseModel):
    """Response with parsed folder channels.

    Returned by:
        - makefeed-telegram: After parsing the folder invite
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(description="Whether parsing was successful")
    usernames: list[str] = Field(
        default_factory=list, description="List of public channel usernames"
    )
    error: str | None = Field(default=None, description="Error message if failed")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "usernames": ["durov", "telegram", "tginfo"],
            }
        }
    )


class WarmMediaCacheRequest(BaseModel):
    """Request to warm media cache for a list of media objects.

    Sent by:
        - makefeed-processor: Before publishing PostCreatedEvent

    Handled by:
        - makefeed-telegram: Downloads and uploads media to Supabase
    """

    request_id: UUID = Field(default_factory=uuid4)
    media_objects: list[dict[str, Any]] = Field(
        description="List of media objects with url, type, preview_url"
    )
    timeout_seconds: float = Field(
        default=30.0, description="Maximum time to wait for caching"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "media_objects": [
                    {"type": "photo", "url": "https://api.example.com/media/..."},
                    {"type": "video", "url": "...", "preview_url": "..."},
                ],
                "timeout_seconds": 30.0,
            }
        }
    )


class WarmMediaCacheResponse(BaseModel):
    """Response with media cache warming results.

    Returned by:
        - makefeed-telegram: After caching media
    """

    request_id: UUID = Field(description="Original request ID for correlation")
    success: bool = Field(
        description="Whether caching completed (may have partial failures)"
    )
    cached: int = Field(default=0, description="Number of media objects cached")
    skipped: int = Field(
        default=0, description="Number of media objects already cached"
    )
    errors: int = Field(
        default=0, description="Number of media objects that failed to cache"
    )
    timed_out: bool = Field(
        default=False, description="Whether the operation timed out"
    )
    error: str | None = Field(
        default=None, description="Error message if completely failed"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "request_id": "550e8400-e29b-41d4-a716-446655440000",
                "success": True,
                "cached": 5,
                "skipped": 2,
                "errors": 0,
                "timed_out": False,
            }
        }
    )


NATS_SUBJECTS = {
    "channel_resolve": "telegram.channel.resolve",
    "get_messages": "telegram.messages.get",
    "refetch_message": "telegram.message.refetch",
    "download_media": "telegram.media.download",
    "parse_folder_invite": "telegram.folder.parse",
    "warm_media_cache": "telegram.media.warm",
}
