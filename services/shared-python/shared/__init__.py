"""Shared package for all makefeed microservices.

This package contains common code shared across all services:
- Database: Connection pool, table definitions
- NATS: Client, publisher, request-reply utilities
- Events: Event schemas for inter-service communication
- Enums: Shared enumeration types
- Config: Base configuration settings
"""

from shared.config import BaseServiceSettings
from shared.enums import (
    FeedType,
    MessageType,
    PollingTier,
    PrePromptType,
    RawType,
    SourceType,
    SubscriptionPlanType,
    SubscriptionPlatform,
    SubscriptionStatus,
    TransactionType,
    TriggerType,
)

__version__ = "0.1.0"

__all__ = [
    # Config
    "BaseServiceSettings",
    # Enums
    "FeedType",
    "MessageType",
    "PollingTier",
    "PrePromptType",
    "RawType",
    "SourceType",
    "SubscriptionPlanType",
    "SubscriptionPlatform",
    "SubscriptionStatus",
    "TransactionType",
    "TriggerType",
]
