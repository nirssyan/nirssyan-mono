"""add_system_to_subscription_platform

Revision ID: a2b3c4d5e6f7
Revises: f7a8b9c0d1e2
Create Date: 2026-02-12

"""

from collections.abc import Sequence

from alembic import op

revision: str = "a2b3c4d5e6f7"
down_revision: str | None = "f7a8b9c0d1e2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE subscription_platform ADD VALUE IF NOT EXISTS 'SYSTEM'")


def downgrade() -> None:
    raise NotImplementedError(
        "Downgrading enum values is not supported. "
        "PostgreSQL does not allow removing enum values."
    )
