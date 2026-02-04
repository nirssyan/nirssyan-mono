"""add_source_url_to_raw_posts

Revision ID: f6d2896f6ee8
Revises: a4c89858b634
Create Date: 2025-10-10 15:59:11.088808

IDEMPOTENT VERSION: This migration is a safety wrapper around a4c89858b634.
It checks if the column already exists before adding it, making it safe to run
even if the previous migration already added the column.

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f6d2896f6ee8"
down_revision: str | None = "a4c89858b634"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add source_url column to raw_posts table (idempotent)
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col["name"] for col in inspector.get_columns("raw_posts")]

    if "source_url" not in columns:
        op.add_column("raw_posts", sa.Column("source_url", sa.Text(), nullable=True))


def downgrade() -> None:
    # Remove source_url column from raw_posts table
    op.drop_column("raw_posts", "source_url")
