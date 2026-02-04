"""add_telegram_users_table

Revision ID: 373f364e7282
Revises: b283a9eaf9f2
Create Date: 2025-11-30 16:33:46.812928

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID

revision: str = "373f364e7282"
down_revision: str | None = "b283a9eaf9f2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "telegram_users",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("telegram_id", sa.BigInteger, nullable=False, unique=True),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("telegram_username", sa.Text, nullable=True),
        sa.Column("telegram_first_name", sa.Text, nullable=True),
        sa.Column(
            "linked_at",
            TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(["user_id"], ["auth.users.id"], ondelete="CASCADE"),
    )

    op.create_index("idx_telegram_users_telegram_id", "telegram_users", ["telegram_id"])
    op.create_index("idx_telegram_users_user_id", "telegram_users", ["user_id"])


def downgrade() -> None:
    op.drop_index("idx_telegram_users_user_id", table_name="telegram_users")
    op.drop_index("idx_telegram_users_telegram_id", table_name="telegram_users")
    op.drop_table("telegram_users")
