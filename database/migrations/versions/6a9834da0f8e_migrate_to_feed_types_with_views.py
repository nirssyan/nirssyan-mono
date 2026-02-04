"""migrate to feed types with views

Revision ID: 6a9834da0f8e
Revises: f60b69a3e939
Create Date: 2025-11-04 18:28:40.963373

This migration adds the views JSONB column to posts table to track view statistics.
Part 1 of 3 in the feed types refactoring (views → enums → rename).

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "6a9834da0f8e"
down_revision: str | None = "f60b69a3e939"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Add views column
    op.add_column(
        "posts",
        sa.Column("views", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.execute("UPDATE posts SET views = '{}'::jsonb WHERE views IS NULL")
    op.alter_column(
        "posts", "views", nullable=False, server_default=sa.text("'{}'::jsonb")
    )
    op.create_index("idx_posts_views_gin", "posts", ["views"], postgresql_using="gin")


def downgrade() -> None:
    op.drop_index("idx_posts_views_gin", table_name="posts")
    op.drop_column("posts", "views")
