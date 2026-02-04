"""Add WebSub columns to raw_feeds.

Revision ID: 37f4200cd354
Revises: 69af56181077
Create Date: 2026-01-31 12:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "37f4200cd354"
down_revision: str | None = "69af56181077"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("raw_feeds", sa.Column("websub_hub_url", sa.Text))
    op.add_column("raw_feeds", sa.Column("websub_topic_url", sa.Text))
    op.add_column(
        "raw_feeds",
        sa.Column("websub_lease_expires", sa.DateTime(timezone=True)),
    )
    op.add_column("raw_feeds", sa.Column("websub_secret", sa.Text))


def downgrade() -> None:
    op.drop_column("raw_feeds", "websub_secret")
    op.drop_column("raw_feeds", "websub_lease_expires")
    op.drop_column("raw_feeds", "websub_topic_url")
    op.drop_column("raw_feeds", "websub_hub_url")
