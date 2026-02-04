"""add_posts_seen_table

Revision ID: 764aef5b7dd5
Revises: 71604c17ece4
Create Date: 2025-10-06 10:28:46.582197

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "764aef5b7dd5"
down_revision: str | None = "71604c17ece4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create posts_seen table for tracking viewed posts."""
    op.create_table(
        "posts_seen",
        sa.Column(
            "id",
            sa.BigInteger,
            primary_key=True,
            autoincrement=True,
            server_default=sa.Identity(start=1, increment=1),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "post_id",
            UUID(as_uuid=True),
            sa.ForeignKey("posts.id", onupdate="CASCADE", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("seen", sa.Boolean, nullable=False, server_default=sa.false()),
    )

    # Create unique index on (user_id, post_id)
    op.create_index(
        "posts_seen_user_id_post_id_uindex",
        "posts_seen",
        ["user_id", "post_id"],
        unique=True,
    )


def downgrade() -> None:
    """Drop posts_seen table."""
    op.drop_index("posts_seen_user_id_post_id_uindex", table_name="posts_seen")
    op.drop_table("posts_seen")
