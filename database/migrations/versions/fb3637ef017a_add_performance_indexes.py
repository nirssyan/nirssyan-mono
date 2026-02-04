"""add_performance_indexes

Revision ID: fb3637ef017a
Revises: 2b26b4ad5828
Create Date: 2025-10-06 14:14:32.580328

This migration adds performance indexes to optimize slow SQL queries.
Analyzed queries from all repositories and identified missing indexes on:
- Foreign keys (JOIN operations)
- WHERE clauses (filtering)
- ORDER BY clauses (sorting)
- Composite indexes for complex queries

Expected performance improvements:
- 10-100x for JOIN queries on foreign keys
- 5-50x for ORDER BY operations
- 2-10x for aggregate queries (MAX, COUNT)
"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "fb3637ef017a"
down_revision: str | None = "2b26b4ad5828"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create performance indexes.

    All indexes are created with IF NOT EXISTS for idempotency.
    """

    # =============================================================================
    # POSTS table indexes
    # Used in: FeedRepository.get_user_feeds_with_posts_and_sources
    # =============================================================================

    # Index for JOIN feeds.id = posts.feed_id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_posts_feed_id
        ON posts (feed_id)
        """
    )

    # Composite index for optimizing queries with feed_id filter + created_at sort
    # Covers: WHERE feed_id = X ORDER BY created_at DESC
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_posts_feed_id_created_at
        ON posts (feed_id, created_at DESC)
        """
    )

    # =============================================================================
    # POSTS_SEEN table indexes
    # Used in: FeedRepository.get_user_feeds_with_posts_and_sources
    # =============================================================================

    # Index for JOIN posts.id = posts_seen.post_id
    # Note: (user_id, post_id) UNIQUE index already exists but not optimal for this JOIN
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_posts_seen_post_id
        ON posts_seen (post_id)
        """
    )

    # =============================================================================
    # SOURCES table indexes
    # Used in: FeedRepository.get_user_feeds_with_posts_and_sources (subquery)
    # =============================================================================

    # Index for subquery: WHERE sources.post_id = posts.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_sources_post_id
        ON sources (post_id)
        """
    )

    # =============================================================================
    # PROMPTS table indexes
    # Used in: FeedRepository.get_feed_with_owner, PromptRepository.*
    # =============================================================================

    # Index for JOIN prompts.feed_id = feeds.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_prompts_feed_id
        ON prompts (feed_id)
        """
    )

    # Index for JOIN prompts.pre_prompt_id = pre_prompts.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_prompts_pre_prompt_id
        ON prompts (pre_prompt_id)
        """
    )

    # =============================================================================
    # PROMPTS_RAW_FEEDS table indexes
    # Used in: RawPostRepository.get_raw_posts_by_prompt
    # =============================================================================

    # Index for WHERE prompts_raw_feeds.prompt_id = X
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_prompts_raw_feeds_prompt_id
        ON prompts_raw_feeds (prompt_id)
        """
    )

    # Index for JOIN prompts_raw_feeds.raw_feed_id = raw_feeds.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_prompts_raw_feeds_raw_feed_id
        ON prompts_raw_feeds (raw_feed_id)
        """
    )

    # =============================================================================
    # RAW_POSTS table indexes
    # Used in: RawPostRepository.get_raw_posts_by_prompt, RawPostRepository.get_by_raw_feed
    # =============================================================================

    # Index for JOIN raw_posts.raw_feed_id = raw_feeds.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_raw_posts_raw_feed_id
        ON raw_posts (raw_feed_id)
        """
    )

    # Index for WHERE created_at > X ORDER BY created_at ASC
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_raw_posts_created_at
        ON raw_posts (created_at ASC)
        """
    )

    # Composite index for optimizing queries with raw_feed_id filter + created_at sort
    # Covers: WHERE raw_feed_id = X AND created_at > Y ORDER BY created_at ASC
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_raw_posts_raw_feed_id_created_at
        ON raw_posts (raw_feed_id, created_at ASC)
        """
    )

    # =============================================================================
    # CHATS table indexes
    # Used in: ChatRepository.get_all_user_chats, ChatRepository.get_chat_with_pre_prompt_and_history
    # =============================================================================

    # Index for WHERE chats.user_id = X
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_chats_user_id
        ON chats (user_id)
        """
    )

    # Index for JOIN chats.pre_prompt_id = pre_prompts.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_chats_pre_prompt_id
        ON chats (pre_prompt_id)
        """
    )

    # Index for ORDER BY chats.created_at DESC
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_chats_created_at
        ON chats (created_at DESC)
        """
    )

    # =============================================================================
    # CHATS_MESSAGES table indexes
    # Used in: ChatRepository.get_all_user_chats (MAX aggregation)
    # =============================================================================

    # Index for JOIN chats_messages.chat_id = chats.id
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_chats_messages_chat_id
        ON chats_messages (chat_id)
        """
    )

    # Composite index for MAX(created_at) aggregation per chat
    # Covers: WHERE chat_id = X ORDER BY created_at DESC (for MAX)
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_chats_messages_chat_id_created_at
        ON chats_messages (chat_id, created_at DESC)
        """
    )

    # =============================================================================
    # PRE_PROMPTS table indexes
    # Used in: PromptRepository.get_filter_prompts_with_sources and similar
    # =============================================================================

    # Index for WHERE pre_prompts.type = X
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_pre_prompts_type
        ON pre_prompts (type)
        """
    )

    # =============================================================================
    # USERS_FEEDS table indexes
    # Used in: MarketplaceRepository.get_marketplace_feeds (CTE with WHERE user_id IN)
    # Note: Composite UNIQUE (user_id, feed_id) exists but separate indexes are faster
    # =============================================================================

    # Index for WHERE users_feeds.user_id = X (CTE in marketplace query)
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_users_feeds_user_id
        ON users_feeds (user_id)
        """
    )

    # Index for WHERE users_feeds.feed_id = X (reverse lookup)
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_users_feeds_feed_id
        ON users_feeds (feed_id)
        """
    )

    # =============================================================================
    # FEEDS table indexes
    # Used in: FeedRepository.get_user_feeds_with_posts_and_sources (ORDER BY)
    # =============================================================================

    # Index for ORDER BY feeds.created_at DESC
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_feeds_created_at
        ON feeds (created_at DESC)
        """
    )

    # =============================================================================
    # RAW_FEEDS table indexes
    # Used in: RawFeedRepository operations with telegram_chat_id
    # =============================================================================

    # Index for WHERE raw_feeds.telegram_chat_id = X
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_raw_feeds_telegram_chat_id
        ON raw_feeds (telegram_chat_id)
        """
    )


def downgrade() -> None:
    """Drop performance indexes."""

    # Drop in reverse order of creation
    op.execute("DROP INDEX IF EXISTS ix_raw_feeds_telegram_chat_id")
    op.execute("DROP INDEX IF EXISTS ix_feeds_created_at")
    op.execute("DROP INDEX IF EXISTS ix_users_feeds_feed_id")
    op.execute("DROP INDEX IF EXISTS ix_users_feeds_user_id")
    op.execute("DROP INDEX IF EXISTS ix_pre_prompts_type")
    op.execute("DROP INDEX IF EXISTS ix_chats_messages_chat_id_created_at")
    op.execute("DROP INDEX IF EXISTS ix_chats_messages_chat_id")
    op.execute("DROP INDEX IF EXISTS ix_chats_created_at")
    op.execute("DROP INDEX IF EXISTS ix_chats_pre_prompt_id")
    op.execute("DROP INDEX IF EXISTS ix_chats_user_id")
    op.execute("DROP INDEX IF EXISTS ix_raw_posts_raw_feed_id_created_at")
    op.execute("DROP INDEX IF EXISTS ix_raw_posts_created_at")
    op.execute("DROP INDEX IF EXISTS ix_raw_posts_raw_feed_id")
    op.execute("DROP INDEX IF EXISTS ix_prompts_raw_feeds_raw_feed_id")
    op.execute("DROP INDEX IF EXISTS ix_prompts_raw_feeds_prompt_id")
    op.execute("DROP INDEX IF EXISTS ix_prompts_pre_prompt_id")
    op.execute("DROP INDEX IF EXISTS ix_prompts_feed_id")
    op.execute("DROP INDEX IF EXISTS ix_sources_post_id")
    op.execute("DROP INDEX IF EXISTS ix_posts_seen_post_id")
    op.execute("DROP INDEX IF EXISTS ix_posts_feed_id_created_at")
    op.execute("DROP INDEX IF EXISTS ix_posts_feed_id")
