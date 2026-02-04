"""Add WEBSITE to raw_type enum.

Revision ID: a1b2c3d4e5f7
Revises: 236389197a9c
Create Date: 2026-02-03 12:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "a1b2c3d4e5f7"
down_revision: str | None = "236389197a9c"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE raw_type ADD VALUE IF NOT EXISTS 'WEBSITE'")


def downgrade() -> None:
    pass
