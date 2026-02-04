"""add telegram_link_codes table

Revision ID: 94c17776769e
Revises: fb3637ef017a
Create Date: 2026-01-08 00:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "94c17776769e"
down_revision: str | None = "20260104_feedtype"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "telegram_link_codes",
        sa.Column("code", sa.String(16), primary_key=True),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "idx_telegram_link_codes_user_id", "telegram_link_codes", ["user_id"]
    )
    op.create_index(
        "idx_telegram_link_codes_expires_at", "telegram_link_codes", ["expires_at"]
    )


def downgrade() -> None:
    op.drop_index("idx_telegram_link_codes_expires_at")
    op.drop_index("idx_telegram_link_codes_user_id")
    op.drop_table("telegram_link_codes")
