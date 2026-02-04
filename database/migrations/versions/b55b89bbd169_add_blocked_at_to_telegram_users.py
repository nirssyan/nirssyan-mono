"""add_blocked_at_to_telegram_users

Revision ID: b55b89bbd169
Revises: 373f364e7282
Create Date: 2025-12-06 14:37:50.076636

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b55b89bbd169"
down_revision: str | None = "373f364e7282"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "telegram_users",
        sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("telegram_users", "blocked_at")
