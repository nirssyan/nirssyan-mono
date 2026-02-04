from enum import StrEnum


class MessageType(StrEnum):
    """Message types with uppercase names but lowercase database values for compatibility."""

    AI = "AI"
    HUMAN = "HUMAN"


class SourceType(StrEnum):
    """Source types with uppercase names but lowercase database values for compatibility."""

    RSS = "RSS"
    SEARCH = "SEARCH"


class RawType(StrEnum):
    """Source types for feed parsing.

    RSS - Direct RSS/Atom feed parsing via feedparser
    TELEGRAM - Telegram channels and groups
    WEBSITE - Website (auto-selects best method: compares RSS vs HTML freshness)
    YOUTUBE - YouTube channels (polled via RSS)
    REDDIT - Reddit subreddits/users (polled via RSS)
    """

    RSS = "RSS"
    TELEGRAM = "TELEGRAM"
    WEBSITE = "WEBSITE"
    YOUTUBE = "YOUTUBE"
    REDDIT = "REDDIT"


class TriggerType(StrEnum):
    """Trigger types with uppercase names but lowercase database values for compatibility."""

    NEW_POST = "NEW_POST"
    CRON = "CRON"


class FeedType(StrEnum):
    """Feed types with uppercase names but lowercase database values for compatibility."""

    SINGLE_POST = "SINGLE_POST"
    DIGEST = "DIGEST"


class PrePromptType(StrEnum):
    """Pre-prompt types with uppercase names but lowercase database values for compatibility."""

    SINGLE_POST = "SINGLE_POST"
    DIGEST = "DIGEST"


class SubscriptionPlanType(StrEnum):
    """Subscription plan types."""

    FREE = "FREE"
    PRO = "PRO"


class SubscriptionPlatform(StrEnum):
    """Subscription platforms."""

    RUSTORE = "RUSTORE"
    GOOGLE_PLAY = "GOOGLE_PLAY"
    APPLE = "APPLE"
    MANUAL = "MANUAL"


class SubscriptionStatus(StrEnum):
    """Subscription status."""

    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"
    PENDING = "PENDING"


class TransactionType(StrEnum):
    """Transaction types for subscription operations."""

    PURCHASE = "PURCHASE"
    RENEWAL = "RENEWAL"
    CANCELLATION = "CANCELLATION"
    VALIDATION = "VALIDATION"
    MANUAL = "MANUAL"
    WEBHOOK = "WEBHOOK"


class PollingTier(StrEnum):
    """Telegram background polling priority tiers."""

    HOT = "HOT"  # High priority: poll every 30s (channels actively used in prompts)
    WARM = "WARM"  # Normal priority: poll every 2 min (channels with recent usage)
    COLD = "COLD"  # Low priority: poll every 10 min (inactive channels)
    QUARANTINE = (
        "QUARANTINE"  # Error state: poll every 60 min (channels with persistent errors)
    )
