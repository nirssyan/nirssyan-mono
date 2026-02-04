"""Add deleted_at column to users table for soft delete.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a8
Create Date: 2026-02-04 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "c3d4e5f6a7b8"
down_revision: str | None = "b2c3d4e5f6a8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "idx_users_deleted_at",
        "users",
        ["deleted_at"],
        postgresql_where=sa.text("deleted_at IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("idx_users_deleted_at", table_name="users")
    op.drop_column("users", "deleted_at")
