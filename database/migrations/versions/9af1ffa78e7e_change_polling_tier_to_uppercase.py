"""change_polling_tier_to_uppercase

Revision ID: 9af1ffa78e7e
Revises: 281a8d53c8d5
Create Date: 2025-11-02 16:34:59.020343

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9af1ffa78e7e"
down_revision: str | None = "281a8d53c8d5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TABLE raw_feeds ALTER COLUMN polling_tier DROP DEFAULT")

    op.execute("ALTER TABLE raw_feeds ALTER COLUMN polling_tier TYPE TEXT")

    op.execute("DROP TYPE IF EXISTS pollingtier CASCADE")

    polling_tier_enum = sa.Enum(
        "HOT",
        "WARM",
        "COLD",
        "QUARANTINE",
        name="pollingtier",
        create_type=True,
    )
    polling_tier_enum.create(op.get_bind())

    op.execute("UPDATE raw_feeds SET polling_tier = UPPER(polling_tier)")

    op.execute(
        "ALTER TABLE raw_feeds ALTER COLUMN polling_tier TYPE pollingtier USING polling_tier::pollingtier"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE raw_feeds ALTER COLUMN polling_tier TYPE TEXT")

    op.execute("DROP TYPE IF EXISTS pollingtier")

    polling_tier_enum = sa.Enum(
        "hot",
        "warm",
        "cold",
        "quarantine",
        name="pollingtier",
        create_type=True,
    )
    polling_tier_enum.create(op.get_bind())

    op.execute("UPDATE raw_feeds SET polling_tier = LOWER(polling_tier)")

    op.execute(
        "ALTER TABLE raw_feeds ALTER COLUMN polling_tier TYPE pollingtier USING polling_tier::pollingtier"
    )
