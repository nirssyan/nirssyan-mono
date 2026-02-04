"""Add YOUTUBE and REDDIT to raw_type enum.

Revision ID: 69af56181077
Revises: 9bb11ceb31ed
Create Date: 2026-01-31 12:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "69af56181077"
down_revision: str | None = "9bb11ceb31ed"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE raw_type ADD VALUE IF NOT EXISTS 'YOUTUBE'")
    op.execute("ALTER TYPE raw_type ADD VALUE IF NOT EXISTS 'REDDIT'")


def downgrade() -> None:
    pass
