"""add_telegram_background_polling_fields

Revision ID: d14bb474e8ea
Revises: e9b04a660859
Create Date: 2025-10-25 11:29:53.916234

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d14bb474e8ea"
down_revision: str | None = "e9b04a660859"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add fields for background Telegram polling
    op.add_column(
        "raw_feeds",
        sa.Column(
            "last_polled_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Last time background worker polled this channel",
        ),
    )
    op.add_column(
        "raw_feeds",
        sa.Column(
            "last_message_id",
            sa.Text,
            nullable=True,
            comment="Last Telegram message ID for incremental fetching",
        ),
    )
    op.add_column(
        "raw_feeds",
        sa.Column(
            "poll_error_count",
            sa.Integer,
            nullable=False,
            server_default="0",
            comment="Number of consecutive polling errors (for error handling)",
        ),
    )


def downgrade() -> None:
    # Remove background polling fields
    op.drop_column("raw_feeds", "poll_error_count")
    op.drop_column("raw_feeds", "last_message_id")
    op.drop_column("raw_feeds", "last_polled_at")
