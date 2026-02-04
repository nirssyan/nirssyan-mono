"""add_title_to_pre_prompts

Revision ID: 94a61e4d17c8
Revises: 65719414d9c7
Create Date: 2025-10-06 22:47:12.471910

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "94a61e4d17c8"
down_revision: str | None = "65719414d9c7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("pre_prompts", sa.Column("title", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("pre_prompts", "title")
