"""add prompts_raw_feeds_offsets table for offset-based processing

Revision ID: fd018bfb23ac
Revises: 24f4e163300b
Create Date: 2025-10-17 13:48:20.108643

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "fd018bfb23ac"
down_revision: str | None = "24f4e163300b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create prompts_raw_feeds_offsets table for offset-based processing.

    This table stores the last processed raw_post_id for each combination of
    (prompt_id, raw_feed_id), enabling granular offset tracking per source.
    This prevents race conditions when new raw_posts are added during processing.
    """
    # Create new table
    op.create_table(
        "prompts_raw_feeds_offsets",
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

    # Add indexes for performance
    op.create_index(
        "idx_prompts_raw_feeds_offsets_prompt_id",
        "prompts_raw_feeds_offsets",
        ["prompt_id"],
    )
    op.create_index(
        "idx_prompts_raw_feeds_offsets_raw_feed_id",
        "prompts_raw_feeds_offsets",
        ["raw_feed_id"],
    )
    # Composite index for efficient offset lookups in CTE query
    op.create_index(
        "idx_offset_lookup",
        "prompts_raw_feeds_offsets",
        ["prompt_id", "raw_feed_id", "last_processed_raw_post_id"],
    )


def downgrade() -> None:
    """Remove prompts_raw_feeds_offsets table.

    Note: Dropping the table automatically drops all indexes,
    so we don't need to explicitly drop them.
    """
    # Drop table (indexes and constraints are dropped automatically)
    op.drop_table("prompts_raw_feeds_offsets")
