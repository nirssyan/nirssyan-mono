"""Create marketplace_feeds table.

Revision ID: a1b2c3d4e5f8
Revises: c3d4e5f6a7b8
Create Date: 2026-02-09 12:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "a1b2c3d4e5f8"
down_revision: str | None = "c3d4e5f6a7b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE marketplace_feeds (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('SINGLE_POST', 'DIGEST')),
            description TEXT,
            tags TEXT[] DEFAULT '{}',
            sources JSONB NOT NULL DEFAULT '[]',
            story TEXT
        )
    """)


def downgrade() -> None:
    op.execute("DROP TABLE marketplace_feeds")
