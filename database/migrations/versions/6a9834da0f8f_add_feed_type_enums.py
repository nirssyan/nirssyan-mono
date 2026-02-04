"""add feed type enums

Revision ID: 6a9834da0f8f
Revises: 6a9834da0f8e
Create Date: 2025-11-23 00:00:00.000000

This migration adds SINGLE_POST and DIGEST values to tgfeedenum.
Part 2 of 3 in the feed types refactoring (views → enums → rename).

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "6a9834da0f8f"
down_revision: str | None = "6a9834da0f8e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 2. Update Enum (requires commit in some PG versions/configs)
    connection = op.get_bind()
    connection.execute(sa.text("COMMIT"))
    connection.execute(
        sa.text("ALTER TYPE tgfeedenum ADD VALUE IF NOT EXISTS 'SINGLE_POST'")
    )
    connection.execute(
        sa.text("ALTER TYPE tgfeedenum ADD VALUE IF NOT EXISTS 'DIGEST'")
    )


def downgrade() -> None:
    # Removing values from an enum is not directly supported in PostgreSQL
    pass
