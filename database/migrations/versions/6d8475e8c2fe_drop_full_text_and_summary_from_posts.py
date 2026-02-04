"""drop full_text and summary from posts

Revision ID: 6d8475e8c2fe
Revises: 1147fa3a0a89
Create Date: 2025-11-28 00:36:48.812743

This migration removes the deprecated full_text and summary columns from posts table.
Data is now stored in the views JSONB column.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "6d8475e8c2fe"
down_revision: str | None = "1147fa3a0a89"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Migrate any remaining full_text data to views JSONB (if not already there)
    op.execute("""
        UPDATE posts
        SET views = views || jsonb_build_object('full_text', full_text)
        WHERE full_text IS NOT NULL
          AND (views->>'full_text') IS NULL
    """)

    # Migrate any remaining summary data to views JSONB (if not already there)
    op.execute("""
        UPDATE posts
        SET views = views || jsonb_build_object('overview', summary)
        WHERE summary IS NOT NULL
          AND (views->>'overview') IS NULL
    """)

    # Drop the columns
    op.drop_column("posts", "full_text")
    op.drop_column("posts", "summary")


def downgrade() -> None:
    # Re-add the columns
    op.add_column(
        "posts",
        sa.Column("full_text", sa.Text(), nullable=True),
    )
    op.add_column(
        "posts",
        sa.Column("summary", sa.Text(), nullable=True),
    )

    # Restore data from views JSONB
    op.execute("""
        UPDATE posts
        SET full_text = views->>'full_text'
        WHERE views->>'full_text' IS NOT NULL
    """)

    op.execute("""
        UPDATE posts
        SET summary = views->>'overview'
        WHERE views->>'overview' IS NOT NULL
    """)
