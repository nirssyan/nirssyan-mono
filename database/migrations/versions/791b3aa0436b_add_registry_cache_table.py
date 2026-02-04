"""add_registry_cache_table

Revision ID: 791b3aa0436b
Revises: 3dbb705327ff
Create Date: 2026-01-03 20:39:16.206207

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

# revision identifiers, used by Alembic.
revision: str = "791b3aa0436b"
down_revision: str | None = "3dbb705327ff"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "registry_cache",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("registry_name", sa.String(100), nullable=False),
        sa.Column("entry_key", sa.String(500), nullable=False),
        sa.Column("entry_data", JSONB, nullable=False),
        sa.Column(
            "synced_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint(
            "registry_name", "entry_key", name="uq_registry_cache_name_key"
        ),
    )

    op.create_index("idx_registry_cache_name", "registry_cache", ["registry_name"])
    op.create_index("idx_registry_cache_expires", "registry_cache", ["expires_at"])


def downgrade() -> None:
    op.drop_index("idx_registry_cache_expires", table_name="registry_cache")
    op.drop_index("idx_registry_cache_name", table_name="registry_cache")
    op.drop_table("registry_cache")
