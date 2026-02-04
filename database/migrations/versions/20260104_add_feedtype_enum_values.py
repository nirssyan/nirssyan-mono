"""add single_post digest to feedtypeenum

Revision ID: 20260104_feedtype
Revises: f2bafa2d441e
Create Date: 2026-01-04

"""

from collections.abc import Sequence

from alembic import op

revision: str = "20260104_feedtype"
down_revision: str | None = "f2bafa2d441e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE \"FeedTypeEnum\" ADD VALUE IF NOT EXISTS 'SINGLE_POST'")
    op.execute("ALTER TYPE \"FeedTypeEnum\" ADD VALUE IF NOT EXISTS 'DIGEST'")
    # Only update if RSS exists in the enum (production migration)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_enum
                WHERE enumtypid = '"FeedTypeEnum"'::regtype
                AND enumlabel = 'RSS'
            ) THEN
                UPDATE feeds SET type = 'SINGLE_POST' WHERE type = 'RSS';
            END IF;
        END $$;
    """)


def downgrade() -> None:
    # Only downgrade if RSS exists in the enum (production rollback)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_enum
                WHERE enumtypid = '"FeedTypeEnum"'::regtype
                AND enumlabel = 'RSS'
            ) THEN
                UPDATE feeds SET type = 'RSS' WHERE type = 'SINGLE_POST';
            END IF;
        END $$;
    """)
