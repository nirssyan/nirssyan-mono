"""add moderation fields to posts

Revision ID: f2bafa2d441e
Revises: f53ddfd987b3
Create Date: 2026-01-04 19:35:34.846388

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "f2bafa2d441e"
down_revision: str | None = "f53ddfd987b3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "posts",
        sa.Column("moderation_action", sa.String(20), nullable=True),
    )
    op.add_column(
        "posts",
        sa.Column(
            "moderation_labels",
            JSONB,
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )
    op.add_column(
        "posts",
        sa.Column(
            "moderation_matched_entities",
            JSONB,
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("posts", "moderation_matched_entities")
    op.drop_column("posts", "moderation_labels")
    op.drop_column("posts", "moderation_action")
