"""add_last_flood_wait_at_to_raw_feeds

Revision ID: f60b69a3e939
Revises: 9af1ffa78e7e
Create Date: 2025-11-02 18:17:59.552359

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f60b69a3e939"
down_revision: str | None = "9af1ffa78e7e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "raw_feeds",
        sa.Column("last_flood_wait_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("raw_feeds", "last_flood_wait_at")
