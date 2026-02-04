"""add filters column to pre_prompts

Revision ID: 1147fa3a0a89
Revises: 0dae84ed0839
Create Date: 2025-11-28 00:16:58.614655

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "1147fa3a0a89"
down_revision: str | None = "0dae84ed0839"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "pre_prompts", sa.Column("filters", postgresql.ARRAY(sa.Text()), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("pre_prompts", "filters")
