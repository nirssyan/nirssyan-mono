"""add_manual_to_subscription_enums

Revision ID: a855f8324e5a
Revises: 907f9b1d4220
Create Date: 2025-10-12 19:52:46.478739

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a855f8324e5a"
down_revision: str | None = "907f9b1d4220"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add MANUAL value to subscription_platform enum
    op.execute("ALTER TYPE subscription_platform ADD VALUE IF NOT EXISTS 'MANUAL'")

    # Add MANUAL value to transaction_type enum
    op.execute("ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'MANUAL'")


def downgrade() -> None:
    # NOTE: PostgreSQL does not support removing values from ENUMs.
    # To downgrade, you would need to:
    # 1. Create new enums without 'MANUAL'
    # 2. Alter all columns to use the new enums
    # 3. Drop the old enums
    # This is complex and risky in production, so we don't implement it.
    # If you need to downgrade, consider manual intervention.
    raise NotImplementedError(
        "Downgrading enum values is not supported. "
        "PostgreSQL does not allow removing enum values."
    )
