"""add posts_seen unique constraint and pk

Revision ID: b2c3d4e5f700
Revises: a1b2c3d4e600
Create Date: 2026-02-17 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op

revision: str = "b2c3d4e5f700"
down_revision: Union[str, None] = "a1b2c3d4e600"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_primary_key("posts_seen_pkey", "posts_seen", ["id"])
    op.create_index(
        "posts_seen_user_id_post_id_uindex",
        "posts_seen",
        ["user_id", "post_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("posts_seen_user_id_post_id_uindex", table_name="posts_seen")
    op.drop_constraint("posts_seen_pkey", "posts_seen", type_="primary")
