"""make telegram_users.user_id nullable and drop fkey

Revision ID: dcf4b788abac
Revises: b55b89bbd169
Create Date: 2025-12-06 17:29:29.109161

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "dcf4b788abac"
down_revision: str | None = "b55b89bbd169"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        "telegram_users_user_id_fkey", "telegram_users", type_="foreignkey"
    )
    op.alter_column("telegram_users", "user_id", existing_type=sa.UUID(), nullable=True)


def downgrade() -> None:
    op.alter_column(
        "telegram_users", "user_id", existing_type=sa.UUID(), nullable=False
    )
    op.create_foreign_key(
        "telegram_users_user_id_fkey",
        "telegram_users",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
