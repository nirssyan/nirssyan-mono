"""add_telegram_polling_tiers

Revision ID: 281a8d53c8d5
Revises: d14bb474e8ea
Create Date: 2025-10-25 11:42:25.560269

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "281a8d53c8d5"
down_revision: str | None = "d14bb474e8ea"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Create ENUM type for polling tiers
    polling_tier_enum = sa.Enum(
        "hot",  # High priority: channels actively used in prompts (poll every 30s)
        "warm",  # Normal priority: channels with recent usage (poll every 2 min)
        "cold",  # Low priority: inactive channels (poll every 10 min)
        "quarantine",  # Error state: channels with persistent errors (poll every 60 min)
        name="pollingtier",
        create_type=True,
    )
    polling_tier_enum.create(op.get_bind(), checkfirst=True)

    # Add polling_tier column (default: warm)
    op.add_column(
        "raw_feeds",
        sa.Column(
            "polling_tier",
            sa.Enum("hot", "warm", "cold", "quarantine", name="pollingtier"),
            nullable=False,
            server_default="warm",
            comment="Polling priority tier: hot (30s), warm (2min), cold (10min), quarantine (60min)",
        ),
    )

    # Add priority_boost_until column for user-triggered priority boost
    op.add_column(
        "raw_feeds",
        sa.Column(
            "priority_boost_until",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Temporary priority boost expiration time (set by user actions)",
        ),
    )

    # Add tier_updated_at to track when tier was last recalculated
    op.add_column(
        "raw_feeds",
        sa.Column(
            "tier_updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            server_default=sa.func.now(),
            comment="Timestamp when polling tier was last updated",
        ),
    )


def downgrade() -> None:
    # Drop columns in reverse order
    op.drop_column("raw_feeds", "tier_updated_at")
    op.drop_column("raw_feeds", "priority_boost_until")
    op.drop_column("raw_feeds", "polling_tier")

    # Drop ENUM type
    op.execute("DROP TYPE IF EXISTS pollingtier")
