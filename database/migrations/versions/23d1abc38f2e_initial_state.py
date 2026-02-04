"""initial_state

Revision ID: 23d1abc38f2e
Revises:
Create Date: 2025-09-26 20:35:00.000000

"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY, ENUM, JSONB, UUID

# revision identifiers, used by Alembic.
revision = "23d1abc38f2e"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create custom vector type for pgvector extension
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # Create ENUM types
    op.execute("CREATE TYPE \"ChatMessageType\" AS ENUM ('USER', 'ASSISTANT')")
    op.execute("CREATE TYPE \"FeedTypeEnum\" AS ENUM ('SINGLE_POST', 'DIGEST')")
    op.execute("CREATE TYPE \"raw_type\" AS ENUM ('RSS', 'TELEGRAM')")
    op.execute("CREATE TYPE \"PromptTriggerEnum\" AS ENUM ('NEW_POST', 'CRON')")
    op.execute(
        "CREATE TYPE \"tgfeedenum\" AS ENUM ('FILTER', 'SUMMARY', 'COMMENT', 'READ')"
    )

    # Create pre_prompts table
    op.create_table(
        "pre_prompts",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("prompt", sa.Text(), nullable=True),
        sa.Column("sources", ARRAY(sa.Text()), nullable=True),
        sa.Column("suggestions", ARRAY(sa.Text()), nullable=True),
        sa.Column(
            "type",
            ENUM(
                "FILTER",
                "SUMMARY",
                "COMMENT",
                "READ",
                name="tgfeedenum",
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column("is_ready_to_create_feed", sa.Boolean(), nullable=True),
    )

    # Create chats table
    op.create_table(
        "chats",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("pre_prompt_id", UUID(as_uuid=True), nullable=True),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
    )
    op.create_foreign_key(
        "fk_chats_pre_prompt_id",
        "chats",
        "pre_prompts",
        ["pre_prompt_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create chats_messages table
    op.create_table(
        "chats_messages",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("chat_id", UUID(as_uuid=True), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "type",
            ENUM("USER", "ASSISTANT", name="ChatMessageType", create_type=False),
            nullable=False,
        ),
    )
    op.create_foreign_key(
        "fk_chats_messages_chat_id",
        "chats_messages",
        "chats",
        ["chat_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create feeds table
    op.create_table(
        "feeds",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column(
            "type",
            ENUM("RSS", "TELEGRAM", name="FeedTypeEnum", create_type=False),
            nullable=True,
        ),
    )

    # Create posts table
    op.create_table(
        "posts",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
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
            server_default=sa.text("gen_random_uuid()"),
            nullable=True,
        ),
        sa.Column("full_text", sa.Text(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("title", sa.Text(), nullable=True),
        sa.Column("media_urls", ARRAY(sa.Text()), nullable=True),
    )
    op.create_foreign_key(
        "fk_posts_feed_id",
        "posts",
        "feeds",
        ["feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create documents table
    op.create_table(
        "documents",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("metadata", JSONB(), nullable=True),
        sa.Column("embedding", sa.Text(), nullable=True),  # vector type placeholder
        sa.Column("post_id", UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_foreign_key(
        "fk_documents_post_id",
        "documents",
        "posts",
        ["post_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    # Change embedding column to vector type
    op.execute(
        "ALTER TABLE documents ALTER COLUMN embedding TYPE vector USING embedding::vector"
    )

    # Create n8n_chat_histories table
    op.create_table(
        "n8n_chat_histories",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("message", JSONB(), nullable=False),
    )

    # Create prompts table
    op.create_table(
        "prompts",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "trigger_type",
            ENUM("NEW_POST", "CRON", name="PromptTriggerEnum", create_type=False),
            nullable=True,
        ),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("cron", sa.Text(), nullable=True),
        sa.Column("last_execution", sa.DateTime(timezone=True), nullable=True),
        sa.Column("feed_id", UUID(as_uuid=True), nullable=True),
        sa.Column("raw_prompt", sa.Text(), server_default="", nullable=True),
        sa.Column(
            "tg_feed_type",
            ENUM(
                "FILTER",
                "SUMMARY",
                "COMMENT",
                "READ",
                name="tgfeedenum",
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column("pre_prompt_id", UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_prompts_feed_id",
        "prompts",
        "feeds",
        ["feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_prompts_pre_prompt_id",
        "prompts",
        "pre_prompts",
        ["pre_prompt_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create raw_feeds table
    op.create_table(
        "raw_feeds",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column(
            "raw_type",
            ENUM("RSS", "TELEGRAM", name="raw_type", create_type=False),
            nullable=True,
        ),
        sa.Column("feed_url", sa.Text(), nullable=True),
        sa.Column("site_url", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("telegram_chat_id", sa.BigInteger(), nullable=True),
        sa.Column("telegram_username", sa.Text(), nullable=True),
        sa.Column("last_execution", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_unique_constraint("uq_raw_feeds_feed_url", "raw_feeds", ["feed_url"])
    op.create_index(
        "ix_raw_feeds_telegram_username",
        "raw_feeds",
        ["telegram_username"],
        unique=False,
    )

    # Create raw_posts table
    op.create_table(
        "raw_posts",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("raw_feed_id", UUID(as_uuid=True), nullable=True),
        sa.Column("image_urls", ARRAY(sa.Text()), nullable=False),
        sa.Column("rp_unique_code", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=True),
    )
    op.create_foreign_key(
        "fk_raw_posts_raw_feed_id",
        "raw_posts",
        "raw_feeds",
        ["raw_feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_unique_constraint(
        "uq_raw_posts_rp_unique_code", "raw_posts", ["rp_unique_code"]
    )

    # Create prompts_raw_feeds table
    op.create_table(
        "prompts_raw_feeds",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("raw_feed_id", UUID(as_uuid=True), nullable=False),
        sa.Column("prompt_id", UUID(as_uuid=True), nullable=False),
    )
    op.create_foreign_key(
        "fk_prompts_raw_feeds_raw_feed_id",
        "prompts_raw_feeds",
        "raw_feeds",
        ["raw_feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_prompts_raw_feeds_prompt_id",
        "prompts_raw_feeds",
        "prompts",
        ["prompt_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create prompts_raw_posts table
    op.create_table(
        "prompts_raw_posts",
        sa.Column(
            "id",
            sa.BigInteger(),
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
        sa.Column("prompt_id", UUID(as_uuid=True), nullable=True),
        sa.Column("raw_post_id", UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_prompts_raw_posts_prompt_id",
        "prompts_raw_posts",
        "prompts",
        ["prompt_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_prompts_raw_posts_raw_post_id",
        "prompts_raw_posts",
        "raw_posts",
        ["raw_post_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create rss_feeds_subscriptions table
    op.create_table(
        "rss_feeds_subscriptions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("link_orig", sa.Text(), nullable=True),
        sa.Column("link_feed", sa.Text(), nullable=False),
        sa.Column(
            "raw_feed_id",
            UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=True,
        ),
    )
    op.create_foreign_key(
        "fk_rss_feeds_subscriptions_raw_feed_id",
        "rss_feeds_subscriptions",
        "raw_feeds",
        ["raw_feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_unique_constraint(
        "uq_rss_feeds_subscriptions_link_feed", "rss_feeds_subscriptions", ["link_feed"]
    )

    # Create sources table
    op.create_table(
        "sources",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("post_id", UUID(as_uuid=True), nullable=True),
        sa.Column("source_url", sa.Text(), nullable=True),
    )
    op.create_foreign_key(
        "fk_sources_post_id",
        "sources",
        "posts",
        ["post_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create users_feeds table
    op.create_table(
        "users_feeds",
        sa.Column(
            "id",
            sa.BigInteger(),
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
        sa.Column("user_id", UUID(as_uuid=True), nullable=True),
        sa.Column("feed_id", UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_users_feeds_feed_id",
        "users_feeds",
        "feeds",
        ["feed_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )
    op.create_index(
        "users_feeds_user_id_feed_id_uindex",
        "users_feeds",
        ["user_id", "feed_id"],
        unique=True,
    )

    # Note: wrappers_fdw_stats is a Supabase system table, not managed by this migration


def downgrade() -> None:
    # Drop tables in reverse order (wrappers_fdw_stats removed - Supabase system table)
    op.drop_table("users_feeds")
    op.drop_table("sources")
    op.drop_table("rss_feeds_subscriptions")
    op.drop_table("prompts_raw_posts")
    op.drop_table("prompts_raw_feeds")
    op.drop_table("raw_posts")
    op.drop_table("raw_feeds")
    op.drop_table("prompts")
    op.drop_table("n8n_chat_histories")
    op.drop_table("documents")
    op.drop_table("posts")
    op.drop_table("feeds")
    op.drop_table("chats_messages")
    op.drop_table("chats")
    op.drop_table("pre_prompts")

    # Drop ENUM types
    op.execute('DROP TYPE IF EXISTS "tgfeedenum"')
    op.execute('DROP TYPE IF EXISTS "PromptTriggerEnum"')
    op.execute('DROP TYPE IF EXISTS "raw_type"')
    op.execute('DROP TYPE IF EXISTS "FeedTypeEnum"')
    op.execute('DROP TYPE IF EXISTS "ChatMessageType"')

    # Drop vector extension
    op.execute("DROP EXTENSION IF EXISTS vector")
