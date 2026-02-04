"""add_moderation_columns_to_raw_posts

Revision ID: 3dbb705327ff
Revises: 4766415dfafc
Create Date: 2026-01-03 20:16:45.816114

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision: str = "3dbb705327ff"
down_revision: str | None = "4766415dfafc"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "raw_posts",
        sa.Column("moderation_action", sa.String(20), nullable=True),
    )
    op.add_column(
        "raw_posts",
        sa.Column("moderation_labels", JSONB, server_default="[]", nullable=False),
    )
    op.add_column(
        "raw_posts",
        sa.Column(
            "moderation_block_reasons", JSONB, server_default="[]", nullable=False
        ),
    )
    op.add_column(
        "raw_posts",
        sa.Column("moderation_checked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "idx_raw_posts_moderation_action",
        "raw_posts",
        ["moderation_action"],
    )


def downgrade() -> None:
    op.drop_index("idx_raw_posts_moderation_action", table_name="raw_posts")
    op.drop_column("raw_posts", "moderation_checked_at")
    op.drop_column("raw_posts", "moderation_block_reasons")
    op.drop_column("raw_posts", "moderation_labels")
    op.drop_column("raw_posts", "moderation_action")
