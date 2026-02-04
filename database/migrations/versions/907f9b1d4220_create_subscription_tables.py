"""create_subscription_tables

Revision ID: 907f9b1d4220
Revises: f70501d09c52
Create Date: 2025-10-12 18:43:22.139479

"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ENUM, JSONB, UUID

# revision identifiers, used by Alembic.
revision: str = "907f9b1d4220"
down_revision: str | None = "f70501d09c52"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    # Create ENUM types for subscriptions
    op.execute("CREATE TYPE subscription_plan_type AS ENUM ('FREE', 'PRO')")
    op.execute(
        "CREATE TYPE subscription_platform AS ENUM ('RUSTORE', 'GOOGLE_PLAY', 'APPLE')"
    )
    op.execute(
        "CREATE TYPE subscription_status AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED', 'PENDING')"
    )
    op.execute(
        "CREATE TYPE transaction_type AS ENUM ('PURCHASE', 'RENEWAL', 'CANCELLATION', 'VALIDATION')"
    )

    # Create subscription_plans table
    op.create_table(
        "subscription_plans",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "plan_type",
            ENUM(
                "FREE",
                "PRO",
                name="subscription_plan_type",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column("feeds_limit", sa.Integer(), nullable=False),
        sa.Column("sources_per_feed_limit", sa.Integer(), nullable=False),
        sa.Column("price_amount_micros", sa.BigInteger(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_unique_constraint(
        "uq_subscription_plans_plan_type", "subscription_plans", ["plan_type"]
    )

    # Create user_subscriptions table
    op.create_table(
        "user_subscriptions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column(
            "subscription_plan_id",
            UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "platform",
            ENUM(
                "RUSTORE",
                "GOOGLE_PLAY",
                "APPLE",
                name="subscription_platform",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column("platform_subscription_id", sa.Text(), nullable=True),
        sa.Column("platform_order_id", sa.Text(), nullable=True),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expiry_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "is_auto_renewing", sa.Boolean(), server_default=sa.false(), nullable=False
        ),
        sa.Column(
            "status",
            ENUM(
                "ACTIVE",
                "EXPIRED",
                "CANCELLED",
                "PENDING",
                name="subscription_status",
                create_type=False,
            ),
            server_default="PENDING",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # Add FK constraint to subscription_plans
    op.create_foreign_key(
        "fk_user_subscriptions_subscription_plan_id",
        "user_subscriptions",
        "subscription_plans",
        ["subscription_plan_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="RESTRICT",
    )

    # Create indexes for user_subscriptions
    op.create_index(
        "idx_user_subscriptions_user_status",
        "user_subscriptions",
        ["user_id", "status"],
    )
    op.create_index(
        "idx_user_subscriptions_expiry",
        "user_subscriptions",
        ["expiry_date"],
        postgresql_where=sa.text("status = 'ACTIVE'"),
    )

    # Partial unique constraint: only one ACTIVE subscription per user
    op.execute(
        """
        CREATE UNIQUE INDEX uq_user_subscriptions_user_active
        ON user_subscriptions (user_id)
        WHERE status = 'ACTIVE'
        """
    )

    # Create subscription_transactions table
    op.create_table(
        "subscription_transactions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "user_subscription_id",
            UUID(as_uuid=True),
            nullable=True,
        ),
        sa.Column(
            "transaction_type",
            ENUM(
                "PURCHASE",
                "RENEWAL",
                "CANCELLATION",
                "VALIDATION",
                name="transaction_type",
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column("platform_response", JSONB(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # Add FK constraint to user_subscriptions
    op.create_foreign_key(
        "fk_subscription_transactions_user_subscription_id",
        "subscription_transactions",
        "user_subscriptions",
        ["user_subscription_id"],
        ["id"],
        onupdate="CASCADE",
        ondelete="CASCADE",
    )

    # Create index for subscription_transactions
    op.create_index(
        "idx_subscription_transactions_subscription",
        "subscription_transactions",
        ["user_subscription_id"],
    )

    # Insert default subscription plans
    op.execute(
        """
        INSERT INTO subscription_plans (plan_type, feeds_limit, sources_per_feed_limit, price_amount_micros, is_active)
        VALUES
            ('FREE', 5, 3, 0, true),
            ('PRO', 10, 10, NULL, true)
        """
    )


def downgrade() -> None:
    # Drop tables in reverse order
    op.drop_table("subscription_transactions")
    op.drop_table("user_subscriptions")
    op.drop_table("subscription_plans")

    # Drop ENUM types
    op.execute("DROP TYPE IF EXISTS transaction_type")
    op.execute("DROP TYPE IF EXISTS subscription_status")
    op.execute("DROP TYPE IF EXISTS subscription_platform")
    op.execute("DROP TYPE IF EXISTS subscription_plan_type")
