"""NATS event schemas for inter-service communication."""

from shared.events.digest_scheduled import DigestScheduledEvent
from shared.events.feed_created import FeedCreatedEvent
from shared.events.feed_initial_sync import FeedInitialSyncEvent
from shared.events.post_created import PostCreatedEvent
from shared.events.raw_post_created import RawPostCreatedEvent
from shared.events.source_validation import (
    TelegramValidationRequest,
    TelegramValidationResponse,
    WebValidationRequest,
    WebValidationResponse,
)
from shared.events.telegram_operations import (
    NATS_SUBJECTS,
    ChannelResolveRequest,
    ChannelResolveResponse,
    DownloadMediaRequest,
    DownloadMediaResponse,
    GetMessagesRequest,
    GetMessagesResponse,
    RefetchMessageRequest,
    RefetchMessageResponse,
    TelegramMessageData,
)

__all__ = [
    "DigestScheduledEvent",
    "FeedCreatedEvent",
    "FeedInitialSyncEvent",
    "PostCreatedEvent",
    "RawPostCreatedEvent",
    "TelegramValidationRequest",
    "TelegramValidationResponse",
    "WebValidationRequest",
    "WebValidationResponse",
    "ChannelResolveRequest",
    "ChannelResolveResponse",
    "GetMessagesRequest",
    "GetMessagesResponse",
    "TelegramMessageData",
    "RefetchMessageRequest",
    "RefetchMessageResponse",
    "DownloadMediaRequest",
    "DownloadMediaResponse",
    "NATS_SUBJECTS",
]
