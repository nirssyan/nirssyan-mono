"""Fix device_tokens missing PK, unique constraint and indexes.

The original migration (235e1dc30e99) defined constraints, but they were
not applied to the dev database.  This migration adds them back.

Revision ID: a1b2c3d4e5f6
Revises: e5f6a7b8c9d0
Create Date: 2026-02-12 22:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: str | None = "e5f6a7b8c9d0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conrelid = 'device_tokens'::regclass AND contype = 'p'
            ) THEN
                ALTER TABLE device_tokens ADD PRIMARY KEY (id);
            END IF;
        END$$;
    """)

    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'device_tokens_token_key'
            ) THEN
                ALTER TABLE device_tokens ADD CONSTRAINT device_tokens_token_key UNIQUE (token);
            END IF;
        END$$;
    """)

    op.create_index(
        "device_tokens_user_id_idx",
        "device_tokens",
        ["user_id"],
        if_not_exists=True,
    )
    op.create_index(
        "device_tokens_user_id_active_idx",
        "device_tokens",
        ["user_id", "is_active"],
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_index("device_tokens_user_id_active_idx", table_name="device_tokens")
    op.drop_index("device_tokens_user_id_idx", table_name="device_tokens")
    op.drop_constraint("device_tokens_token_key", "device_tokens", type_="unique")
