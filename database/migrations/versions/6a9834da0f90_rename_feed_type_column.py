"""rename feed type column

Revision ID: 6a9834da0f90
Revises: 6a9834da0f8f
Create Date: 2025-11-23 00:00:01.000000

This migration migrates old feed types to new ones and renames tg_feed_type to feed_type.
Part 3 of 3 in the feed types refactoring (views → enums → rename).

Migration mapping:
- FILTER, READ, COMMENT → SINGLE_POST
- SUMMARY → DIGEST

Also converts prompt column from TEXT to JSONB with structure:
{
  "instruction": "<original prompt text>",
  "filters": ["remove_ads"]
}

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "6a9834da0f90"
down_revision: str | None = "6a9834da0f8f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 3. Update Prompts and Rename Column
    op.execute(
        "UPDATE prompts SET tg_feed_type = 'SINGLE_POST' WHERE tg_feed_type IN ('FILTER', 'READ', 'COMMENT')"
    )
    op.execute(
        "UPDATE prompts SET tg_feed_type = 'DIGEST' WHERE tg_feed_type = 'SUMMARY'"
    )

    op.alter_column("prompts", "tg_feed_type", new_column_name="feed_type")

    op.execute("""
        ALTER TABLE prompts
        ALTER COLUMN prompt TYPE jsonb
        USING jsonb_build_object(
            'instruction', prompt::text,
            'filters', jsonb_build_array('remove_ads')
        )
    """)


def downgrade() -> None:
    op.execute("""
        UPDATE prompts
        SET prompt = prompt->>'instruction'
        WHERE jsonb_typeof(prompt) = 'object'
    """)

    op.alter_column("prompts", "prompt", type_=sa.Text())

    op.execute(
        "UPDATE prompts SET feed_type = 'FILTER' WHERE feed_type = 'SINGLE_POST'"
    )
    op.execute("UPDATE prompts SET feed_type = 'SUMMARY' WHERE feed_type = 'DIGEST'")

    op.alter_column("prompts", "feed_type", new_column_name="tg_feed_type")
