"""Shared Pydantic models for all makefeed microservices.

These models are used for request/response serialization across services.
"""

# Chat models
# Auth models
from shared.models.auth import DemoLoginRequest, DemoLoginResponse
from shared.models.chat import (
    ChatMessageInList,
    ChatMessageRequest,
    ChatMessageResponse,
    ChatResponse,
    ChatsListResponse,
    ChatWithMessagesResponse,
    CompleteChatMessageResponse,
    CurrentFeedInfoResponse,
    DeleteChatRequest,
    LimitExceptionResponse,
    UpdateFeedPreviewRequest,
    UpdateFeedPreviewResponse,
)

# Device token models
from shared.models.device_token import (
    RegisterDeviceTokenRequest,
    RegisterDeviceTokenResponse,
    UnregisterDeviceTokenRequest,
    UnregisterDeviceTokenResponse,
)

# Feed models
from shared.models.feed import (
    CreateFeedFullRequest,
    CreateFeedFullResponse,
    CreateFeedRequest,
    CreateFeedResponse,
    FeedCreationData,
    FeedOwnerResponse,
    FeedRequest,
    FeedResponse,
    FeedViewResponse,
    GenerateTitleResponse,
    PostData,
    RawFeedRequest,
    RawFeedResponse,
    ReadAllPostsResponse,
    RenameFeedRequest,
    RenameFeedResponse,
    SourceInput,
)
from shared.models.feed import (
    SourceData as FeedSourceData,
)

# Feedback models
from shared.models.feedback import CreateFeedbackResponse

# Filter/processing models
from shared.models.filter import (
    FeedProcessingRequest,
    FeedProcessingResponse,
    FilteredPostData,
    FilterPromptData,
    ProcessingResult,
    RSSItem,
)

# Marketplace models
from shared.models.marketplace import (
    MarketplaceFeedItem,
    MarketplaceRequest,
    MarketplaceResponse,
    SetMarketplaceFeedsRequest,
    SetMarketplaceFeedsResponse,
)

# Media models
from shared.models.media import (
    AnimationMediaObject,
    BaseMediaObject,
    DocumentMediaObject,
    PhotoMediaObject,
    VideoMediaObject,
)

# Post models
from shared.models.post import (
    PostResponse,
    PostResponseV2,
    PostViewsV2,
)
from shared.models.post import (
    SourceData as PostSourceData,
)

# Post seen models
from shared.models.post_seen import (
    MarkPostsSeenRequest,
    MarkPostsSeenResponse,
)

# Prompt models
from shared.models.prompt import (
    PrePromptRequest,
    PrePromptResponse,
    PromptRequest,
    PromptResponse,
)

# Prompt example models
from shared.models.prompt_example import (
    PromptExampleResponse,
    PromptExamplesListResponse,
)

# RuStore webhook models
from shared.models.rustore_webhook import (
    RuStoreWebhookPayload,
    RuStoreWebhookProcessingResult,
    RuStoreWebhookRequest,
    RuStoreWebhookResponse,
)

# Source validation models
from shared.models.source_validation import (
    SourceValidationRequest,
    SourceValidationResponse,
)

# Subscription models
from shared.models.subscription import (
    CurrentSubscriptionResponse,
    ManualSubscriptionRequest,
    ManualSubscriptionResponse,
    SubscriptionPlanResponse,
    SubscriptionWithLimitsResponse,
    ValidateSubscriptionRequest,
    ValidateSubscriptionResponse,
)

# Suggestion models
from shared.models.suggestion import SuggestionResponse

# Summarize models
from shared.models.summarize import (
    SummarizeUnseenPostViews,
    SummarizeUnseenResponse,
    SummarizeUnseenSourceInfo,
)

# Tag models
from shared.models.tag import (
    TagInfo,
    TagResponse,
    UpdateUserTagsRequest,
    UpdateUserTagsResponse,
    UserTagResponse,
)

# Telegram link models
from shared.models.telegram_link import (
    TelegramAccountInfo,
    TelegramLinkUrlResponse,
    TelegramStatusResponse,
    TelegramUnlinkResponse,
)

# User models
from shared.models.user import DeleteUserResponse

# Users feed models
from shared.models.users_feed import (
    CreateUsersFeedRequest,
    CreateUsersFeedResponse,
    DeleteUsersFeedResponse,
)

__all__ = [
    # Auth
    "DemoLoginRequest",
    "DemoLoginResponse",
    # Chat
    "ChatMessageInList",
    "ChatMessageRequest",
    "ChatMessageResponse",
    "ChatResponse",
    "ChatsListResponse",
    "ChatWithMessagesResponse",
    "CompleteChatMessageResponse",
    "CurrentFeedInfoResponse",
    "DeleteChatRequest",
    "LimitExceptionResponse",
    "UpdateFeedPreviewRequest",
    "UpdateFeedPreviewResponse",
    # Device token
    "RegisterDeviceTokenRequest",
    "RegisterDeviceTokenResponse",
    "UnregisterDeviceTokenRequest",
    "UnregisterDeviceTokenResponse",
    # Feed
    "CreateFeedFullRequest",
    "CreateFeedFullResponse",
    "CreateFeedRequest",
    "CreateFeedResponse",
    "FeedCreationData",
    "FeedOwnerResponse",
    "FeedRequest",
    "FeedResponse",
    "FeedSourceData",
    "FeedViewResponse",
    "GenerateTitleResponse",
    "PostData",
    "RawFeedRequest",
    "RawFeedResponse",
    "ReadAllPostsResponse",
    "RenameFeedRequest",
    "RenameFeedResponse",
    "SourceInput",
    # Feedback
    "CreateFeedbackResponse",
    # Filter/processing
    "FeedProcessingRequest",
    "FeedProcessingResponse",
    "FilteredPostData",
    "FilterPromptData",
    "ProcessingResult",
    "RSSItem",
    # Marketplace
    "MarketplaceFeedItem",
    "MarketplaceRequest",
    "MarketplaceResponse",
    "SetMarketplaceFeedsRequest",
    "SetMarketplaceFeedsResponse",
    # Media
    "AnimationMediaObject",
    "BaseMediaObject",
    "DocumentMediaObject",
    "PhotoMediaObject",
    "VideoMediaObject",
    # Post seen
    "MarkPostsSeenRequest",
    "MarkPostsSeenResponse",
    # Post
    "PostResponse",
    "PostResponseV2",
    "PostSourceData",
    "PostViewsV2",
    # Prompt example
    "PromptExampleResponse",
    "PromptExamplesListResponse",
    # Prompt
    "PrePromptRequest",
    "PrePromptResponse",
    "PromptRequest",
    "PromptResponse",
    # RuStore
    "RuStoreWebhookPayload",
    "RuStoreWebhookProcessingResult",
    "RuStoreWebhookRequest",
    "RuStoreWebhookResponse",
    # Source validation
    "SourceValidationRequest",
    "SourceValidationResponse",
    # Subscription
    "CurrentSubscriptionResponse",
    "ManualSubscriptionRequest",
    "ManualSubscriptionResponse",
    "SubscriptionPlanResponse",
    "SubscriptionWithLimitsResponse",
    "ValidateSubscriptionRequest",
    "ValidateSubscriptionResponse",
    # Suggestion
    "SuggestionResponse",
    # Summarize
    "SummarizeUnseenPostViews",
    "SummarizeUnseenResponse",
    "SummarizeUnseenSourceInfo",
    # Tag
    "TagInfo",
    "TagResponse",
    "UpdateUserTagsRequest",
    "UpdateUserTagsResponse",
    "UserTagResponse",
    # Telegram link
    "TelegramAccountInfo",
    "TelegramLinkUrlResponse",
    "TelegramStatusResponse",
    "TelegramUnlinkResponse",
    # User
    "DeleteUserResponse",
    # Users feed
    "CreateUsersFeedRequest",
    "CreateUsersFeedResponse",
    "DeleteUsersFeedResponse",
]
