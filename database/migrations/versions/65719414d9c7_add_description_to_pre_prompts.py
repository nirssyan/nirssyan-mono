"""add_description_to_pre_prompts

Revision ID: 65719414d9c7
Revises: fb3637ef017a
Create Date: 2025-10-06 22:30:02.535345

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "65719414d9c7"
down_revision: str | None = "fb3637ef017a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add description column to pre_prompts table
    op.add_column("pre_prompts", sa.Column("description", sa.Text(), nullable=True))


def downgrade() -> None:
    # Remove description column from pre_prompts table
    op.drop_column("pre_prompts", "description")
