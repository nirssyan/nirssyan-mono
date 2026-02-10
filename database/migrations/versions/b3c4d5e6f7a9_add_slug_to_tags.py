"""add_slug_to_tags

Revision ID: b3c4d5e6f7a9
Revises: a1b2c3d4e5f8
Create Date: 2026-02-10

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b3c4d5e6f7a9"
down_revision: str | None = "a1b2c3d4e5f8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("tags", sa.Column("slug", sa.Text(), nullable=True))

    op.execute(
        sa.text(
            """
            UPDATE tags
            SET slug = lower(regexp_replace(name, '[^a-zA-Zа-яА-ЯёЁ0-9]+', '-', 'g'))
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE tags
            SET slug = trim(both '-' from slug)
            WHERE slug LIKE '-%' OR slug LIKE '%-'
            """
        )
    )

    op.alter_column("tags", "slug", nullable=False)
    op.create_unique_constraint("tags_slug_key", "tags", ["slug"])


def downgrade() -> None:
    op.drop_constraint("tags_slug_key", "tags", type_="unique")
    op.drop_column("tags", "slug")
