"""Update Cursor blog raw_type from RSS to WEBSITE.

Revision ID: b2c3d4e5f6a8
Revises: a1b2c3d4e5f7
Create Date: 2026-02-03 12:01:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "b2c3d4e5f6a8"
down_revision: str | None = "a1b2c3d4e5f7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        UPDATE raw_feeds
        SET raw_type = 'WEBSITE'
        WHERE id = 'ae260def-a113-4b82-be4b-7d5b03dfcd90'
        AND raw_type = 'RSS'
    """)


def downgrade() -> None:
    op.execute("""
        UPDATE raw_feeds
        SET raw_type = 'RSS'
        WHERE id = 'ae260def-a113-4b82-be4b-7d5b03dfcd90'
        AND raw_type = 'WEBSITE'
    """)
