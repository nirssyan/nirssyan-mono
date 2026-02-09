from typing import Any

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY, ENUM, JSONB, TIMESTAMP, UUID
from sqlalchemy.types import UserDefinedType

from shared.enums import (
    FeedType,
    MessageType,
    PollingTier,
    PrePromptType,
    RawType,
    SubscriptionPlanType,
    SubscriptionPlatform,
    SubscriptionStatus,
    TransactionType,
    TriggerType,
)

metadata = sa.MetaData()


class VectorType(UserDefinedType):
    """Custom type for PostgreSQL vector extension"""

    def get_col_spec(self, **kw: Any) -> str:
        return "vector"


# ENUM types
message_type_enum = ENUM(MessageType, name="ChatMessageType", metadata=metadata)
source_type_enum = ENUM(FeedType, name="FeedTypeEnum", metadata=metadata)
raw_type_enum = ENUM(RawType, name="raw_type", metadata=metadata)
trigger_type_enum = ENUM(TriggerType, name="PromptTriggerEnum", metadata=metadata)
feed_type_enum = ENUM(FeedType, name="tgfeedenum", metadata=metadata)
pre_prompt_type_enum = ENUM(PrePromptType, name="tgfeedenum", metadata=metadata)

# Subscription ENUM types
subscription_plan_type_enum = ENUM(
    SubscriptionPlanType, name="subscription_plan_type", metadata=metadata
)
subscription_platform_enum = ENUM(
    SubscriptionPlatform, name="subscription_platform", metadata=metadata
)
subscription_status_enum = ENUM(
    SubscriptionStatus, name="subscription_status", metadata=metadata
)
transaction_type_enum = ENUM(
    TransactionType, name="transaction_type", metadata=metadata
)

# Telegram background polling ENUM
polling_tier_enum = ENUM(PollingTier, name="pollingtier", metadata=metadata)

# Tables
alembic_version = sa.Table(
    "alembic_version",
    metadata,
    sa.Column("version_num", sa.String, nullable=False, primary_key=True),
)

pre_prompts = sa.Table(
    "pre_prompts",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("prompt", sa.Text),
    sa.Column("sources", ARRAY(sa.Text)),
    sa.Column("suggestions", ARRAY(sa.Text)),
    sa.Column("type", pre_prompt_type_enum),
    sa.Column("is_ready_to_create_feed", sa.Boolean),
    sa.Column("description", sa.Text),
    sa.Column("title", sa.Text),
    sa.Column("tags", ARRAY(sa.Text)),
    sa.Column(
        "source_types",
        JSONB,
        comment="Mapping of source URL to parser type (RSS, TELEGRAM, etc)",
    ),
    sa.Column(
        "digest_interval_hours",
        sa.Integer,
        nullable=True,
        comment="Interval in hours between digest generation (1-48). Only for DIGEST type. NULL means default 12 hours.",
    ),
    sa.Column("filters", ARRAY(sa.Text)),
    sa.Column("filter_ads", sa.Boolean, server_default=sa.false()),
    sa.Column("filter_duplicates", sa.Boolean, server_default=sa.false()),
    sa.Column(
        "views_raw",
        ARRAY(sa.Text),
        comment="User-defined view descriptions (e.g., ['read as if I'm 5'])",
    ),
    sa.Column(
        "filters_raw",
        ARRAY(sa.Text),
        comment="User-defined filter descriptions (e.g., ['no ads'])",
    ),
)

chats = sa.Table(
    "chats",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "pre_prompt_id",
        UUID(as_uuid=True),
        sa.ForeignKey("pre_prompts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
)

chats_messages = sa.Table(
    "chats_messages",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "chat_id",
        UUID(as_uuid=True),
        sa.ForeignKey("chats.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column("message", sa.Text, nullable=False),
    sa.Column("type", message_type_enum, nullable=False),
    sa.Column("sequence", sa.BigInteger, nullable=False),
)

feeds = sa.Table(
    "feeds",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("name", sa.Text, nullable=False),
    sa.Column("description", sa.Text),
    sa.Column("tags", ARRAY(sa.Text)),
    sa.Column("type", source_type_enum),
    sa.Column("is_marketplace", sa.Boolean, nullable=False, server_default=sa.false()),
    sa.Column(
        "is_creating_finished", sa.Boolean, nullable=True, server_default=sa.false()
    ),
    sa.Column(
        "chat_id",
        UUID(as_uuid=True),
        sa.ForeignKey("chats.id", onupdate="CASCADE", ondelete="SET NULL"),
        nullable=True,
        unique=True,
    ),
)

tags = sa.Table(
    "tags",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("name", sa.Text, nullable=False, unique=True),
)

users_tags = sa.Table(
    "users_tags",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column(
        "tag_id",
        UUID(as_uuid=True),
        sa.ForeignKey("tags.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Index("users_tags_user_id_tag_id_uindex", "user_id", "tag_id", unique=True),
)

prompt_examples = sa.Table(
    "prompt_examples",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("prompt", sa.Text, nullable=False),
)

prompt_examples_tags = sa.Table(
    "prompt_examples_tags",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "prompt_example_id",
        UUID(as_uuid=True),
        sa.ForeignKey("prompt_examples.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column(
        "tag_id",
        UUID(as_uuid=True),
        sa.ForeignKey("tags.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Index(
        "prompt_examples_tags_prompt_example_id_tag_id_uindex",
        "prompt_example_id",
        "tag_id",
        unique=True,
    ),
)

posts = sa.Table(
    "posts",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "views",
        JSONB,
        nullable=False,
        server_default=sa.text("'{}'::jsonb"),
        comment="JSONB field for different post views (ai_generation, full_text, overview)",
    ),
    sa.Column("image_url", sa.Text),
    sa.Column("title", sa.Text),
    sa.Column(
        "media_objects", sa.JSON, nullable=False, server_default=sa.text("'[]'::jsonb")
    ),
    sa.Column("moderation_action", sa.String(20), nullable=True),
    sa.Column(
        "moderation_labels",
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    ),
    sa.Column(
        "moderation_matched_entities",
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    ),
)

posts_seen = sa.Table(
    "posts_seen",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "post_id",
        UUID(as_uuid=True),
        sa.ForeignKey("posts.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("seen", sa.Boolean, nullable=False, server_default=sa.false()),
    sa.Index("posts_seen_user_id_post_id_uindex", "user_id", "post_id", unique=True),
)

documents = sa.Table(
    "documents",
    metadata,
    sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
    sa.Column("content", sa.Text),
    sa.Column("metadata", JSONB),
    sa.Column("embedding", VectorType()),
    sa.Column(
        "post_id",
        UUID(as_uuid=True),
        sa.ForeignKey("posts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
)

n8n_chat_histories = sa.Table(
    "n8n_chat_histories",
    metadata,
    sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
    sa.Column("session_id", sa.String, nullable=False),
    sa.Column("message", JSONB, nullable=False),
)

prompts = sa.Table(
    "prompts",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("trigger_type", trigger_type_enum),
    sa.Column("prompt", JSONB, nullable=False),
    sa.Column("cron", sa.Text),
    sa.Column("last_execution", sa.DateTime(timezone=True)),
    sa.Column(
        "feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column("raw_prompt", sa.Text, server_default=""),
    sa.Column("feed_type", feed_type_enum),
    sa.Column(
        "pre_prompt_id",
        UUID(as_uuid=True),
        sa.ForeignKey("pre_prompts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column(
        "digest_interval_hours",
        sa.Integer,
        nullable=True,
        comment="Interval in hours between digest generation (1-48). Only for DIGEST type. NULL means default 12 hours.",
    ),
    sa.Column(
        "views_config",
        JSONB,
        nullable=False,
        server_default="[]",
        comment="AI-transformed view configs: [{name: {en, ru}, prompt}]",
    ),
    sa.Column(
        "filters_config",
        JSONB,
        nullable=False,
        server_default="[]",
        comment="AI-transformed filter configs: [{name: {en, ru}, prompt}]",
    ),
)

raw_feeds = sa.Table(
    "raw_feeds",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("name", sa.Text, nullable=False),
    sa.Column("raw_type", raw_type_enum),
    sa.Column("feed_url", sa.Text, unique=True),
    sa.Column("site_url", sa.Text),
    sa.Column("image_url", sa.Text),
    sa.Column("telegram_chat_id", sa.BigInteger),
    sa.Column("telegram_username", sa.Text),
    sa.Column("last_execution", sa.DateTime(timezone=True)),
    sa.Column(
        "last_polled_at",
        sa.DateTime(timezone=True),
        comment="Last time background worker polled this channel",
    ),
    sa.Column(
        "last_message_id",
        sa.Text,
        comment="Last Telegram message ID for incremental fetching",
    ),
    sa.Column(
        "poll_error_count",
        sa.Integer,
        nullable=False,
        server_default=sa.text("0"),
        comment="Number of consecutive polling errors (for error handling)",
    ),
    sa.Column(
        "polling_tier",
        polling_tier_enum,
        nullable=False,
        server_default=sa.text("'WARM'"),
        comment="Polling priority tier: HOT (30s), WARM (2min), COLD (10min), QUARANTINE (60min)",
    ),
    sa.Column(
        "priority_boost_until",
        sa.DateTime(timezone=True),
        comment="Temporary priority boost expiration time (set by user actions)",
    ),
    sa.Column(
        "tier_updated_at",
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
        comment="Timestamp when polling tier was last updated",
    ),
    sa.Column(
        "last_flood_wait_at",
        sa.DateTime(timezone=True),
        comment="Last FloodWait timestamp for rate limiting protection (5min cooldown)",
    ),
    sa.Column("websub_hub_url", sa.Text, comment="WebSub hub URL"),
    sa.Column("websub_topic_url", sa.Text, comment="WebSub self/topic URL"),
    sa.Column(
        "websub_lease_expires",
        sa.DateTime(timezone=True),
        comment="WebSub subscription expiration",
    ),
    sa.Column("websub_secret", sa.Text, comment="WebSub HMAC verification secret"),
)

raw_posts = sa.Table(
    "raw_posts",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("content", sa.Text),
    sa.Column(
        "raw_feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column(
        "media_objects", sa.JSON, nullable=False, server_default=sa.text("'[]'::jsonb")
    ),
    sa.Column("rp_unique_code", sa.Text, nullable=False, unique=True),
    sa.Column("title", sa.Text),
    sa.Column("media_group_id", sa.Text),
    sa.Column("telegram_message_id", sa.BigInteger),
    sa.Column("source_url", sa.Text),
    sa.Column("moderation_action", sa.String(20), nullable=True),
    sa.Column(
        "moderation_labels",
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    ),
    sa.Column(
        "moderation_block_reasons",
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    ),
    sa.Column("moderation_checked_at", sa.DateTime(timezone=True), nullable=True),
    sa.Column(
        "moderation_matched_entities",
        JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    ),
    sa.Index("idx_raw_posts_moderation_action", "moderation_action"),
)

prompts_raw_feeds = sa.Table(
    "prompts_raw_feeds",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "raw_feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column(
        "prompt_id",
        UUID(as_uuid=True),
        sa.ForeignKey("prompts.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.UniqueConstraint(
        "prompt_id", "raw_feed_id", name="uq_prompts_raw_feeds_prompt_raw_feed"
    ),
)

prompts_raw_feeds_offsets = sa.Table(
    "prompts_raw_feeds_offsets",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "updated_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "prompt_id",
        UUID(as_uuid=True),
        sa.ForeignKey("prompts.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column(
        "raw_feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column(
        "last_processed_raw_post_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_posts.id", ondelete="SET NULL"),
        nullable=True,
    ),
    sa.UniqueConstraint("prompt_id", "raw_feed_id", name="uq_prompt_raw_feed"),
)

prompts_raw_posts = sa.Table(
    "prompts_raw_posts",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "prompt_id",
        UUID(as_uuid=True),
        sa.ForeignKey("prompts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column(
        "raw_post_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_posts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
)

rss_feeds_subscriptions = sa.Table(
    "rss_feeds_subscriptions",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("title", sa.Text, nullable=False),
    sa.Column("link_orig", sa.Text),
    sa.Column("link_feed", sa.Text, nullable=False, unique=True),
    sa.Column(
        "raw_feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("raw_feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
        server_default=sa.text("gen_random_uuid()"),
    ),
)

sources = sa.Table(
    "sources",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "post_id",
        UUID(as_uuid=True),
        sa.ForeignKey("posts.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column(
        "feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column("source_url", sa.Text),
    sa.UniqueConstraint("feed_id", "source_url", name="uq_sources_feed_id_source_url"),
)

users_feeds = sa.Table(
    "users_feeds",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("user_id", UUID(as_uuid=True)),
    sa.Column(
        "feed_id",
        UUID(as_uuid=True),
        sa.ForeignKey("feeds.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Index("users_feeds_user_id_feed_id_uindex", "user_id", "feed_id", unique=True),
)

wrappers_fdw_stats = sa.Table(
    "wrappers_fdw_stats",
    metadata,
    sa.Column("fdw_name", sa.Text, nullable=False, primary_key=True),
    sa.Column(
        "create_times",
        sa.BigInteger,
        comment="Total number of times the FDW instance has been created",
    ),
    sa.Column("rows_in", sa.BigInteger, comment="Total rows input from origin"),
    sa.Column("rows_out", sa.BigInteger, comment="Total rows output to Postgres"),
    sa.Column("bytes_in", sa.BigInteger, comment="Total bytes input from origin"),
    sa.Column("bytes_out", sa.BigInteger, comment="Total bytes output to Postgres"),
    sa.Column("metadata", JSONB, comment="Metadata specific for the FDW"),
    sa.Column(
        "created_at",
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("timezone('utc'::text, now())"),
    ),
    sa.Column(
        "updated_at",
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("timezone('utc'::text, now())"),
    ),
    comment="Wrappers Foreign Data Wrapper statistics",
)

# Subscription tables
subscription_plans = sa.Table(
    "subscription_plans",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("plan_type", subscription_plan_type_enum, nullable=False, unique=True),
    sa.Column("feeds_limit", sa.Integer, nullable=False),
    sa.Column("sources_per_feed_limit", sa.Integer, nullable=False),
    sa.Column("price_amount_micros", sa.BigInteger),
    sa.Column("is_active", sa.Boolean, server_default=sa.true(), nullable=False),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
)

user_subscriptions = sa.Table(
    "user_subscriptions",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column(
        "subscription_plan_id",
        UUID(as_uuid=True),
        sa.ForeignKey("subscription_plans.id", onupdate="CASCADE", ondelete="RESTRICT"),
        nullable=False,
    ),
    sa.Column("platform", subscription_platform_enum, nullable=False),
    sa.Column("platform_subscription_id", sa.Text),
    sa.Column("platform_order_id", sa.Text),
    sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
    sa.Column("expiry_date", sa.DateTime(timezone=True), nullable=False),
    sa.Column(
        "is_auto_renewing", sa.Boolean, server_default=sa.false(), nullable=False
    ),
    sa.Column(
        "status", subscription_status_enum, server_default="PENDING", nullable=False
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "updated_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Index("idx_user_subscriptions_user_status", "user_id", "status"),
    sa.Index(
        "idx_user_subscriptions_expiry",
        "expiry_date",
        postgresql_where=sa.text("status = 'ACTIVE'"),
    ),
)

subscription_transactions = sa.Table(
    "subscription_transactions",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "user_subscription_id",
        UUID(as_uuid=True),
        sa.ForeignKey("user_subscriptions.id", onupdate="CASCADE", ondelete="CASCADE"),
    ),
    sa.Column("transaction_type", transaction_type_enum, nullable=False),
    sa.Column("platform_response", JSONB),
    sa.Column("is_sandbox", sa.Boolean, nullable=False, server_default=sa.false()),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Index("idx_subscription_transactions_subscription", "user_subscription_id"),
)

# Feedback table
feedbacks = sa.Table(
    "feedbacks",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("message", sa.Text),
    sa.Column("image_urls", ARRAY(sa.Text)),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
)

# Admin users table
admin_users = sa.Table(
    "admin_users",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False, unique=True),
    sa.Column("is_admin", sa.Boolean, nullable=False, server_default=sa.true()),
    sa.Index("admin_users_user_id_idx", "user_id"),
)

# User social accounts table (OAuth providers)
user_social_accounts = sa.Table(
    "user_social_accounts",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("provider", sa.String(50), nullable=False),
    sa.Column("provider_user_id", sa.String(255), nullable=False),
    sa.Column("provider_email", sa.String(255), nullable=True),
    sa.Column("access_token", sa.Text, nullable=True),
    sa.Column("refresh_token", sa.Text, nullable=True),
    sa.Column("token_expires_at", TIMESTAMP(timezone=True), nullable=True),
    sa.Column("profile_data", JSONB, nullable=True),
    sa.Column(
        "created_at",
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "updated_at",
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.UniqueConstraint("provider", "provider_user_id", name="uq_provider_user"),
    sa.UniqueConstraint("user_id", "provider", name="uq_user_provider"),
    sa.Index("idx_user_social_accounts_user_id", "user_id"),
    sa.Index("idx_user_social_accounts_provider_user", "provider", "provider_user_id"),
    schema="public",
)

# User LLM costs tracking table for billing
user_llm_costs = sa.Table(
    "user_llm_costs",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("agent", sa.String(100), nullable=False),
    sa.Column("model", sa.String(100), nullable=False),
    sa.Column("prompt_tokens", sa.Integer, nullable=False),
    sa.Column("completion_tokens", sa.Integer, nullable=False),
    sa.Column("total_tokens", sa.Integer, nullable=False),
    sa.Column("cost_usd", sa.Numeric(precision=10, scale=6), nullable=False),
    sa.Column(
        "created_at",
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Index("idx_user_llm_costs_user_id", "user_id"),
    sa.Index("idx_user_llm_costs_created_at", "created_at"),
    sa.Index("idx_user_llm_costs_user_created", "user_id", "created_at"),
)

# Device tokens table for FCM push notifications
device_tokens = sa.Table(
    "device_tokens",
    metadata,
    sa.Column(
        "id",
        sa.BigInteger,
        primary_key=True,
        autoincrement=True,
        server_default=sa.Identity(start=1, increment=1),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "updated_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("token", sa.Text, nullable=False),
    sa.Column("platform", sa.String(20), nullable=False),
    sa.Column("device_id", sa.String(255), nullable=True),
    sa.Column("is_active", sa.Boolean, server_default=sa.text("true"), nullable=False),
    sa.UniqueConstraint("token", name="device_tokens_token_key"),
    sa.Index("device_tokens_user_id_idx", "user_id"),
    sa.Index("device_tokens_user_id_active_idx", "user_id", "is_active"),
)

# Telegram users table (for bot account linking)
telegram_users = sa.Table(
    "telegram_users",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("telegram_id", sa.BigInteger, nullable=False, unique=True),
    sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    sa.Column("telegram_username", sa.Text, nullable=True),
    sa.Column("telegram_first_name", sa.Text, nullable=True),
    sa.Column(
        "linked_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
    sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True),
    sa.Index("idx_telegram_users_telegram_id", "telegram_id"),
    sa.Index("idx_telegram_users_user_id", "user_id"),
)

# Registry cache table for moderation registries
registry_cache = sa.Table(
    "registry_cache",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column("registry_name", sa.String(100), nullable=False),
    sa.Column("entry_key", sa.String(500), nullable=False),
    sa.Column("entry_data", JSONB, nullable=False),
    sa.Column(
        "synced_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
    sa.UniqueConstraint(
        "registry_name", "entry_key", name="uq_registry_cache_name_key"
    ),
    sa.Index("idx_registry_cache_name", "registry_name"),
    sa.Index("idx_registry_cache_expires", "expires_at"),
)

# Suggestions table (localized filter/view/source suggestions)
suggestions = sa.Table(
    "suggestions",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "type",
        sa.String(20),
        nullable=False,
        comment="Suggestion type: filter, view, source",
    ),
    sa.Column(
        "name",
        JSONB,
        nullable=False,
        comment="Localized names as JSONB: {en: 'English', ru: 'Русский'}",
    ),
    sa.Column(
        "source_type",
        sa.String(20),
        nullable=True,
        comment="Source type for source suggestions: TELEGRAM, WEBSITE",
    ),
    sa.Index("idx_suggestions_type", "type"),
)

# LLM models registry (synced from OpenRouter API)
llm_models = sa.Table(
    "llm_models",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "model_id",
        sa.String(200),
        nullable=False,
        unique=True,
        comment="OpenRouter model ID (e.g., google/gemini-3-flash-preview)",
    ),
    sa.Column(
        "provider",
        sa.String(100),
        nullable=False,
        comment="Model provider (e.g., google, anthropic, openai)",
    ),
    sa.Column("name", sa.Text, nullable=False, comment="Human-readable model name"),
    sa.Column(
        "model_created_at",
        sa.BigInteger,
        nullable=True,
        comment="Unix timestamp of model creation from OpenRouter API",
    ),
    sa.Column("context_length", sa.Integer, nullable=True),
    sa.Column(
        "input_modalities",
        JSONB,
        nullable=False,
        server_default=sa.text("'[\"text\"]'::jsonb"),
    ),
    sa.Column(
        "output_modalities",
        JSONB,
        nullable=False,
        server_default=sa.text("'[\"text\"]'::jsonb"),
    ),
    sa.Column(
        "price_prompt",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
        server_default="0",
        comment="Price per token for prompt/input (USD)",
    ),
    sa.Column(
        "price_completion",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
        server_default="0",
        comment="Price per token for completion/output (USD)",
    ),
    sa.Column(
        "price_image",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
        server_default="0",
        comment="Price per image (USD)",
    ),
    sa.Column(
        "price_audio",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
        server_default="0",
        comment="Price per audio second (USD)",
    ),
    sa.Column(
        "is_active",
        sa.Boolean,
        nullable=False,
        server_default=sa.true(),
        comment="Whether model is currently available",
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "updated_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column(
        "prices_changed_at",
        sa.DateTime(timezone=True),
        nullable=True,
        comment="Timestamp of last price change",
    ),
    sa.Column(
        "last_synced_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Index("idx_llm_models_provider", "provider"),
    sa.Index("idx_llm_models_created_at", "created_at"),
    sa.Index("idx_llm_models_is_active", "is_active"),
)

# LLM model price change history
llm_model_price_history = sa.Table(
    "llm_model_price_history",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "model_id",
        sa.String(200),
        nullable=False,
        comment="OpenRouter model ID for reference",
    ),
    sa.Column(
        "llm_model_uuid",
        UUID(as_uuid=True),
        sa.ForeignKey("llm_models.id", ondelete="CASCADE"),
        nullable=False,
    ),
    sa.Column(
        "prev_price_prompt",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
    ),
    sa.Column(
        "prev_price_completion",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
    ),
    sa.Column(
        "new_price_prompt",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
    ),
    sa.Column(
        "new_price_completion",
        sa.Numeric(precision=20, scale=12),
        nullable=False,
    ),
    sa.Column(
        "change_percent_prompt",
        sa.Numeric(precision=10, scale=4),
        nullable=True,
        comment="Percentage change for prompt price",
    ),
    sa.Column(
        "change_percent_completion",
        sa.Numeric(precision=10, scale=4),
        nullable=True,
        comment="Percentage change for completion price",
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Index("idx_llm_price_history_model_id", "model_id"),
    sa.Index("idx_llm_price_history_created_at", "created_at"),
)

marketplace_feeds = sa.Table(
    "marketplace_feeds",
    metadata,
    sa.Column(
        "id",
        UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    ),
    sa.Column(
        "created_at",
        sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
    ),
    sa.Column("slug", sa.Text, nullable=False, unique=True),
    sa.Column("name", sa.Text, nullable=False),
    sa.Column("type", sa.Text, nullable=False),
    sa.Column("description", sa.Text),
    sa.Column("tags", ARRAY(sa.Text), server_default=sa.text("'{}'::text[]")),
    sa.Column("sources", JSONB, nullable=False, server_default=sa.text("'[]'::jsonb")),
    sa.Column("story", sa.Text),
    sa.CheckConstraint("type IN ('SINGLE_POST', 'DIGEST')", name="ck_marketplace_feeds_type"),
)

# Convenience exports for commonly used tables
messages = chats_messages
subscriptions = user_subscriptions
social_accounts = user_social_accounts
