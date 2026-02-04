"""add_suggestions_table

Revision ID: 8d5c41dd2830
Revises: f59411dc9e05
Create Date: 2026-01-10 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "8d5c41dd2830"
down_revision: str | None = "f59411dc9e05"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "suggestions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "type",
            sa.String(20),
            nullable=False,
            comment="Suggestion type: filter, view, source",
        ),
        sa.Column(
            "name",
            JSONB,
            nullable=False,
            comment="Localized names as JSONB: {en: 'English', ru: 'Русский'}",
        ),
    )

    op.create_index("idx_suggestions_type", "suggestions", ["type"])


def downgrade() -> None:
    op.drop_index("idx_suggestions_type", table_name="suggestions")
    op.drop_table("suggestions")
