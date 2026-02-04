"""add_digest_interval_hours

Revision ID: 36f685611f4a
Revises: c649f1065131
Create Date: 2025-10-21 17:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "36f685611f4a"
down_revision: str | None = "c649f1065131"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add digest_interval_hours column to pre_prompts and prompts tables."""
    # Add to pre_prompts table
    op.add_column(
        "pre_prompts",
        sa.Column(
            "digest_interval_hours",
            sa.Integer(),
            nullable=True,
            comment="Interval in hours between digest generation (1-48). Only for SUMMARY type. NULL means default 12 hours.",
        ),
    )

    # Add to prompts table
    op.add_column(
        "prompts",
        sa.Column(
            "digest_interval_hours",
            sa.Integer(),
            nullable=True,
            comment="Interval in hours between digest generation (1-48). Only for SUMMARY type. NULL means default 12 hours.",
        ),
    )


def downgrade() -> None:
    """Remove digest_interval_hours column from pre_prompts and prompts tables."""
    op.drop_column("prompts", "digest_interval_hours")
    op.drop_column("pre_prompts", "digest_interval_hours")
