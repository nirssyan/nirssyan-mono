"""Shared repositories for all makefeed microservices.

All repositories use SQLAlchemy Core and work with AsyncConnection.
"""

from shared.repositories.chat import ChatRepository
from shared.repositories.device_token import DeviceTokenRepository
from shared.repositories.feed import FeedRepository
from shared.repositories.feedback import FeedbackRepository
from shared.repositories.llm_model import LlmModelsRepository
from shared.repositories.marketplace import MarketplaceRepository
from shared.repositories.post import PostRepository
from shared.repositories.post_seen import PostSeenRepository
from shared.repositories.prompt import PromptRepository
from shared.repositories.prompt_example import PromptExampleRepository
from shared.repositories.prompt_raw_feed_offset import (
    PromptRawFeedOffsetRepository,
)
from shared.repositories.raw_feed import RawFeedRepository
from shared.repositories.raw_post import RawPostRepository
from shared.repositories.source import SourceRepository
from shared.repositories.subscription import SubscriptionRepository
from shared.repositories.suggestion import SuggestionRepository
from shared.repositories.tag import TagRepository
from shared.repositories.telegram_user import TelegramUserRepository
from shared.repositories.user import UserRepository
from shared.repositories.user_tag import UserTagRepository

__all__ = [
    "ChatRepository",
    "DeviceTokenRepository",
    "FeedRepository",
    "FeedbackRepository",
    "LlmModelsRepository",
    "MarketplaceRepository",
    "PostRepository",
    "PostSeenRepository",
    "PromptRepository",
    "PromptExampleRepository",
    "PromptRawFeedOffsetRepository",
    "RawFeedRepository",
    "RawPostRepository",
    "SourceRepository",
    "SubscriptionRepository",
    "SuggestionRepository",
    "TagRepository",
    "TelegramUserRepository",
    "UserRepository",
    "UserTagRepository",
]
