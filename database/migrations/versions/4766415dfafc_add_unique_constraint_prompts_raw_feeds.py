"""add unique constraint prompts_raw_feeds

Revision ID: 4766415dfafc
Revises: dd1fc8a69c78
Create Date: 2026-01-03 12:00:00.000000

This migration adds a UNIQUE constraint on (prompt_id, raw_feed_id) in
prompts_raw_feeds table to prevent duplicate links.

Before creating the constraint, it removes any existing duplicates by
keeping only the first record (by ctid) for each unique combination.
"""

from collections.abc import Sequence

from alembic import op

revision: str = "4766415dfafc"
down_revision: str | None = "dd1fc8a69c78"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        DELETE FROM prompts_raw_feeds
        WHERE ctid NOT IN (
            SELECT MIN(ctid)
            FROM prompts_raw_feeds
            GROUP BY prompt_id, raw_feed_id
        )
    """)

    op.create_unique_constraint(
        "uq_prompts_raw_feeds_prompt_raw_feed",
        "prompts_raw_feeds",
        ["prompt_id", "raw_feed_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_prompts_raw_feeds_prompt_raw_feed",
        "prompts_raw_feeds",
        type_="unique",
    )
