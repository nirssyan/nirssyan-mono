"""add_source_url_to_raw_posts

Revision ID: a4c89858b634
Revises: ca7c3d6c4d96
Create Date: 2025-10-09 09:43:23.005738

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a4c89858b634"
down_revision: str | None = "ca7c3d6c4d96"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add source_url column to raw_posts table for RSS/Web articles
    op.add_column("raw_posts", sa.Column("source_url", sa.Text(), nullable=True))


def downgrade() -> None:
    # Remove source_url column from raw_posts table
    op.drop_column("raw_posts", "source_url")
