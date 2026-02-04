"""add_user_llm_costs_table

Revision ID: f4361db31dd1
Revises: e47011961b9f
Create Date: 2025-11-16 02:22:46.252727

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4361db31dd1"
down_revision: str | None = "e47011961b9f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_llm_costs",
        sa.Column(
            "id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("agent", sa.String(length=100), nullable=False),
        sa.Column("model", sa.String(length=100), nullable=False),
        sa.Column("prompt_tokens", sa.Integer(), nullable=False),
        sa.Column("completion_tokens", sa.Integer(), nullable=False),
        sa.Column("total_tokens", sa.Integer(), nullable=False),
        sa.Column("cost_usd", sa.Numeric(precision=10, scale=6), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create indexes for efficient queries
    op.create_index("idx_user_llm_costs_user_id", "user_llm_costs", ["user_id"])
    op.create_index("idx_user_llm_costs_created_at", "user_llm_costs", ["created_at"])
    op.create_index(
        "idx_user_llm_costs_user_created", "user_llm_costs", ["user_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("idx_user_llm_costs_user_created", table_name="user_llm_costs")
    op.drop_index("idx_user_llm_costs_created_at", table_name="user_llm_costs")
    op.drop_index("idx_user_llm_costs_user_id", table_name="user_llm_costs")
    op.drop_table("user_llm_costs")
