"""add_feed_creating_status_flag

Revision ID: a06ebfc5abb5
Revises: 36f685611f4a
Create Date: 2025-10-21 17:59:09.485907

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a06ebfc5abb5"
down_revision: str | None = "36f685611f4a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add is_creating_finished column to feeds table
    op.add_column(
        "feeds",
        sa.Column(
            "is_creating_finished", sa.Boolean, nullable=True, server_default=sa.false()
        ),
    )

    # Set is_creating_finished=true for all existing feeds
    # (assume old feeds are already processed)
    op.execute(
        "UPDATE feeds SET is_creating_finished = true WHERE is_creating_finished IS NULL"
    )


def downgrade() -> None:
    # Remove is_creating_finished column
    op.drop_column("feeds", "is_creating_finished")
