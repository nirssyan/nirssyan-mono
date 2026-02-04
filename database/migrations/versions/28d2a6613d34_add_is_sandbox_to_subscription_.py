"""add_is_sandbox_to_subscription_transactions

Revision ID: 28d2a6613d34
Revises: a855f8324e5a
Create Date: 2025-10-12 20:15:09.445835

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "28d2a6613d34"
down_revision: str | None = "a855f8324e5a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add is_sandbox column to subscription_transactions table
    op.add_column(
        "subscription_transactions",
        sa.Column(
            "is_sandbox", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )


def downgrade() -> None:
    # Remove is_sandbox column from subscription_transactions table
    op.drop_column("subscription_transactions", "is_sandbox")
