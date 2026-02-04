"""add_chat_id_to_feeds

Revision ID: b283a9eaf9f2
Revises: 7a1b2c3d4e5f
Create Date: 2025-11-30 02:06:31.060308

This migration adds a chat_id column to feeds table with UNIQUE constraint.
It populates existing data from the relationship chain (feeds <- prompts -> pre_prompts <- chats)
and removes duplicates (keeping the most recent feed per chat_id).

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "b283a9eaf9f2"
down_revision: str | None = "7a1b2c3d4e5f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("feeds", sa.Column("chat_id", UUID(as_uuid=True), nullable=True))

    op.execute("""
        UPDATE feeds
        SET chat_id = subquery.chat_id
        FROM (
            SELECT DISTINCT ON (f.id)
                f.id AS feed_id,
                c.id AS chat_id
            FROM feeds f
            JOIN prompts p ON p.feed_id = f.id
            JOIN pre_prompts pp ON p.pre_prompt_id = pp.id
            JOIN chats c ON c.pre_prompt_id = pp.id
            ORDER BY f.id, c.created_at DESC
        ) AS subquery
        WHERE feeds.id = subquery.feed_id
    """)

    op.execute("""
        DELETE FROM feeds
        WHERE id IN (
            SELECT f.id
            FROM feeds f
            WHERE f.chat_id IS NOT NULL
            AND f.id NOT IN (
                SELECT DISTINCT ON (chat_id) id
                FROM feeds
                WHERE chat_id IS NOT NULL
                ORDER BY chat_id, created_at DESC
            )
        )
    """)

    op.create_unique_constraint("uq_feeds_chat_id", "feeds", ["chat_id"])

    op.create_foreign_key(
        "fk_feeds_chat_id",
        "feeds",
        "chats",
        ["chat_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="SET NULL",
    )

    op.create_index("ix_feeds_chat_id", "feeds", ["chat_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_feeds_chat_id", table_name="feeds")
    op.drop_constraint("fk_feeds_chat_id", "feeds", type_="foreignkey")
    op.drop_constraint("uq_feeds_chat_id", "feeds", type_="unique")
    op.drop_column("feeds", "chat_id")
