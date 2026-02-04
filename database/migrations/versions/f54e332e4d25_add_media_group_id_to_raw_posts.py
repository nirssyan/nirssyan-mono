"""add_media_group_id_to_raw_posts

Revision ID: f54e332e4d25
Revises: 660683040211
Create Date: 2025-10-05 13:04:40.969350

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f54e332e4d25"
down_revision: str | None = "660683040211"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add media_group_id column to raw_posts for Telegram album grouping
    op.add_column("raw_posts", sa.Column("media_group_id", sa.Text(), nullable=True))


def downgrade() -> None:
    # Remove media_group_id column from raw_posts
    op.drop_column("raw_posts", "media_group_id")
