"""add_device_tokens_table

Revision ID: 235e1dc30e99
Revises: 6d8475e8c2fe
Create Date: 2025-11-29 18:00:34.924788

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "235e1dc30e99"
down_revision: str | None = "6d8475e8c2fe"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "device_tokens",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("user_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("token", sa.Text, nullable=False),
        sa.Column("platform", sa.String(20), nullable=False),
        sa.Column("device_id", sa.String(255), nullable=True),
        sa.Column(
            "is_active", sa.Boolean, server_default=sa.text("true"), nullable=False
        ),
        sa.UniqueConstraint("token", name="device_tokens_token_key"),
    )
    op.create_index("device_tokens_user_id_idx", "device_tokens", ["user_id"])
    op.create_index(
        "device_tokens_user_id_active_idx", "device_tokens", ["user_id", "is_active"]
    )


def downgrade() -> None:
    op.drop_index("device_tokens_user_id_active_idx", table_name="device_tokens")
    op.drop_index("device_tokens_user_id_idx", table_name="device_tokens")
    op.drop_table("device_tokens")
