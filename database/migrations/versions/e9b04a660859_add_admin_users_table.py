"""add_admin_users_table

Revision ID: e9b04a660859
Revises: a06ebfc5abb5
Create Date: 2025-10-23 12:13:49.677435

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "e9b04a660859"
down_revision: str | None = "a06ebfc5abb5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "admin_users",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False, unique=True),
        sa.Column("is_admin", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("admin_users_user_id_idx", "admin_users", ["user_id"])


def downgrade() -> None:
    op.drop_index("admin_users_user_id_idx", table_name="admin_users")
    op.drop_table("admin_users")
