"""add_source_type_to_suggestions

Revision ID: a1b2c3d4e5f6
Revises: 8d5c41dd2830
Create Date: 2026-01-10 15:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: str | None = "8d5c41dd2830"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "suggestions",
        sa.Column(
            "source_type",
            sa.String(20),
            nullable=True,
            comment="Source type for source suggestions: TELEGRAM, WEBSITE",
        ),
    )

    op.execute("""
        UPDATE suggestions
        SET source_type = 'TELEGRAM'
        WHERE type = 'source' AND name->>'ru' LIKE '@%'
    """)


def downgrade() -> None:
    op.drop_column("suggestions", "source_type")
