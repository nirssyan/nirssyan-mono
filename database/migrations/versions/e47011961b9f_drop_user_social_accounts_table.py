"""drop user_social_accounts table

Revision ID: e47011961b9f
Revises: c5f3d096dc88
Create Date: 2025-11-16 01:46:44.709591

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "e47011961b9f"
down_revision: str | None = "c5f3d096dc88"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        DROP INDEX IF EXISTS public.idx_user_social_accounts_provider_user;
        DROP INDEX IF EXISTS public.idx_user_social_accounts_user_id;
        DROP TABLE IF EXISTS public.user_social_accounts;
    """)


def downgrade() -> None:
    op.create_table(
        "user_social_accounts",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider", sa.String(length=50), nullable=False),
        sa.Column("provider_user_id", sa.String(length=255), nullable=False),
        sa.Column("provider_email", sa.String(length=255), nullable=True),
        sa.Column("access_token", sa.Text(), nullable=True),
        sa.Column("refresh_token", sa.Text(), nullable=True),
        sa.Column("token_expires_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column(
            "profile_data", postgresql.JSONB(astext_type=sa.Text()), nullable=True
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("NOW()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("NOW()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["auth.users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("provider", "provider_user_id", name="uq_provider_user"),
        sa.UniqueConstraint("user_id", "provider", name="uq_user_provider"),
        schema="public",
    )

    op.create_index(
        "idx_user_social_accounts_user_id",
        "user_social_accounts",
        ["user_id"],
        schema="public",
    )
    op.create_index(
        "idx_user_social_accounts_provider_user",
        "user_social_accounts",
        ["provider", "provider_user_id"],
        schema="public",
    )
