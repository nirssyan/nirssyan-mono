"""add_tag_to_pre_prompts_and_feeds

Revision ID: 0acd396d63e9
Revises: 94a61e4d17c8
Create Date: 2025-10-08 10:44:14.298393

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0acd396d63e9"
down_revision: str | None = "94a61e4d17c8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add tag column to pre_prompts table
    op.add_column("pre_prompts", sa.Column("tag", sa.Text(), nullable=True))

    # Add tag column to feeds table
    op.add_column("feeds", sa.Column("tag", sa.Text(), nullable=True))

    # Set default tag "Другое" for existing records with NULL tag
    op.execute(
        """
        UPDATE pre_prompts
        SET tag = 'Другое'
        WHERE tag IS NULL
        """
    )

    op.execute(
        """
        UPDATE feeds
        SET tag = 'Другое'
        WHERE tag IS NULL
        """
    )


def downgrade() -> None:
    # Remove tag column from feeds table
    op.drop_column("feeds", "tag")

    # Remove tag column from pre_prompts table
    op.drop_column("pre_prompts", "tag")
