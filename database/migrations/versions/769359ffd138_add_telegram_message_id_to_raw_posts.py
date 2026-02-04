"""add telegram_message_id to raw_posts

Revision ID: 769359ffd138
Revises: f54e332e4d25
Create Date: 2025-10-05 13:47:55.236805

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "769359ffd138"
down_revision: str | None = "f54e332e4d25"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add telegram_message_id column to raw_posts for storing actual Telegram message ID
    op.add_column(
        "raw_posts", sa.Column("telegram_message_id", sa.BigInteger(), nullable=True)
    )


def downgrade() -> None:
    # Remove telegram_message_id column from raw_posts
    op.drop_column("raw_posts", "telegram_message_id")
