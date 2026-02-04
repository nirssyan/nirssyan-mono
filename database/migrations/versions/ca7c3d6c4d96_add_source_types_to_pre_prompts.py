"""add source_types to pre_prompts

Revision ID: ca7c3d6c4d96
Revises: fdeb6de72346
Create Date: 2025-10-09 08:24:34.548807

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision: str = "ca7c3d6c4d96"
down_revision: str | None = "fdeb6de72346"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add source_types column to pre_prompts table."""
    op.add_column(
        "pre_prompts",
        sa.Column(
            "source_types",
            JSONB,
            nullable=True,
            comment="Mapping of source URL to parser type (RSS, TELEGRAM, etc)",
        ),
    )


def downgrade() -> None:
    """Remove source_types column from pre_prompts table."""
    op.drop_column("pre_prompts", "source_types")
