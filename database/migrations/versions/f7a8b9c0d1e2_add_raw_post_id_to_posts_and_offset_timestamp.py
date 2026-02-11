"""Add raw_post_id to posts for dedup and timestamp-based offset tracking.

Revision ID: f7a8b9c0d1e2
Revises: e5f6a7b8c9d0
Create Date: 2026-02-11 22:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "f7a8b9c0d1e2"
down_revision: str | None = "e5f6a7b8c9d0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "posts",
        sa.Column(
            "raw_post_id",
            UUID(as_uuid=True),
            sa.ForeignKey("raw_posts.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    op.execute("""
        CREATE UNIQUE INDEX uq_posts_feed_raw_post
          ON posts (feed_id, raw_post_id)
          WHERE raw_post_id IS NOT NULL
    """)

    op.add_column(
        "prompts_raw_feeds_offsets",
        sa.Column(
            "last_processed_created_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.execute("""
        UPDATE prompts_raw_feeds_offsets prfo
        SET last_processed_created_at = (
            SELECT rp.created_at
            FROM raw_posts rp
            WHERE rp.id = prfo.last_processed_raw_post_id
        )
        WHERE prfo.last_processed_raw_post_id IS NOT NULL
    """)


def downgrade() -> None:
    op.drop_column("prompts_raw_feeds_offsets", "last_processed_created_at")
    op.execute("DROP INDEX IF EXISTS uq_posts_feed_raw_post")
    op.drop_column("posts", "raw_post_id")
