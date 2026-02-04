"""restore_polling_tier_default

Revision ID: 0dae84ed0839
Revises: f4361db31dd1
Create Date: 2025-11-23 01:57:08.277902

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0dae84ed0839"
down_revision: str | None = "f4361db31dd1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Set default using explicit enum cast for PostgreSQL
    op.execute(
        "ALTER TABLE raw_feeds ALTER COLUMN polling_tier SET DEFAULT 'WARM'::pollingtier"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE raw_feeds ALTER COLUMN polling_tier DROP DEFAULT")
