"""add_is_marketplace_to_feeds

Revision ID: c649f1065131
Revises: fd018bfb23ac
Create Date: 2025-10-19 00:26:23.599101

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c649f1065131"
down_revision: str | None = "fd018bfb23ac"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add is_marketplace column to feeds table with default value False."""
    op.add_column(
        "feeds",
        sa.Column(
            "is_marketplace",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    """Remove is_marketplace column from feeds table."""
    op.drop_column("feeds", "is_marketplace")
