"""add moderation_matched_entities to raw_posts

Revision ID: f53ddfd987b3
Revises: 791b3aa0436b
Create Date: 2026-01-04 19:20:36.067503

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision: str = "f53ddfd987b3"
down_revision: str | None = "791b3aa0436b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "raw_posts",
        sa.Column(
            "moderation_matched_entities",
            JSONB,
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("raw_posts", "moderation_matched_entities")
