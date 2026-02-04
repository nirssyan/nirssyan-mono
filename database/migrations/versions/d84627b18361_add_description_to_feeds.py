"""add_description_to_feeds

Revision ID: d84627b18361
Revises: 54a1db4c1ca9
Create Date: 2025-10-05 20:33:49.078145

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d84627b18361"
down_revision: str | None = "54a1db4c1ca9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add description column to feeds table."""
    op.add_column("feeds", sa.Column("description", sa.Text(), nullable=True))


def downgrade() -> None:
    """Remove description column from feeds table."""
    op.drop_column("feeds", "description")
