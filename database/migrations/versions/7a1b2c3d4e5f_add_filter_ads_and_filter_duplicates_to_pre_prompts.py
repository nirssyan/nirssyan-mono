"""add_filter_ads_and_filter_duplicates_to_pre_prompts

Revision ID: 7a1b2c3d4e5f
Revises: 235e1dc30e99
Create Date: 2025-11-29 18:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "7a1b2c3d4e5f"
down_revision: str | None = "235e1dc30e99"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "pre_prompts",
        sa.Column("filter_ads", sa.Boolean(), server_default=sa.false(), nullable=True),
    )
    op.add_column(
        "pre_prompts",
        sa.Column(
            "filter_duplicates", sa.Boolean(), server_default=sa.false(), nullable=True
        ),
    )


def downgrade() -> None:
    op.drop_column("pre_prompts", "filter_duplicates")
    op.drop_column("pre_prompts", "filter_ads")
