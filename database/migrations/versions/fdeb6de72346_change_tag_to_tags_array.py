"""change_tag_to_tags_array

Revision ID: fdeb6de72346
Revises: 0acd396d63e9
Create Date: 2025-10-08 13:23:43.337825

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "fdeb6de72346"
down_revision: str | None = "0acd396d63e9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Step 1: Rename existing 'tag' column to 'tag_old' for both tables
    op.alter_column("pre_prompts", "tag", new_column_name="tag_old")
    op.alter_column("feeds", "tag", new_column_name="tag_old")

    # Step 2: Add new 'tags' column as TEXT[] for both tables
    op.add_column("pre_prompts", sa.Column("tags", sa.ARRAY(sa.Text()), nullable=True))
    op.add_column("feeds", sa.Column("tags", sa.ARRAY(sa.Text()), nullable=True))

    # Step 3: Convert data from tag_old to tags (wrap single string in array)
    op.execute(
        """
        UPDATE pre_prompts
        SET tags = ARRAY[tag_old]
        WHERE tag_old IS NOT NULL
        """
    )

    op.execute(
        """
        UPDATE feeds
        SET tags = ARRAY[tag_old]
        WHERE tag_old IS NOT NULL
        """
    )

    # Step 4: Drop old 'tag_old' column
    op.drop_column("pre_prompts", "tag_old")
    op.drop_column("feeds", "tag_old")


def downgrade() -> None:
    # Step 1: Add back old 'tag' column as TEXT
    op.add_column("pre_prompts", sa.Column("tag", sa.Text(), nullable=True))
    op.add_column("feeds", sa.Column("tag", sa.Text(), nullable=True))

    # Step 2: Convert data from tags array to single tag (take first element)
    op.execute(
        """
        UPDATE pre_prompts
        SET tag = tags[1]
        WHERE tags IS NOT NULL AND array_length(tags, 1) > 0
        """
    )

    op.execute(
        """
        UPDATE feeds
        SET tag = tags[1]
        WHERE tags IS NOT NULL AND array_length(tags, 1) > 0
        """
    )

    # Step 3: Drop 'tags' column
    op.drop_column("pre_prompts", "tags")
    op.drop_column("feeds", "tags")
