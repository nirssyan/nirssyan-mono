"""add_dynamic_views_and_filters_columns

Revision ID: dd1fc8a69c78
Revises: dcf4b788abac
Create Date: 2025-12-06 20:02:00.370865

Adds dynamic views and filters support:
- pre_prompts: views_raw, filters_raw (user input arrays)
- prompts: views_config, filters_config (AI-transformed configs)
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY, JSONB

revision: str = "dd1fc8a69c78"
down_revision: str | None = "dcf4b788abac"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Add views_raw and filters_raw to pre_prompts (user input)
    op.add_column(
        "pre_prompts",
        sa.Column(
            "views_raw",
            ARRAY(sa.Text()),
            nullable=True,
            comment="User-defined view descriptions (e.g., ['read as if I'm 5'])",
        ),
    )
    op.add_column(
        "pre_prompts",
        sa.Column(
            "filters_raw",
            ARRAY(sa.Text()),
            nullable=True,
            comment="User-defined filter descriptions (e.g., ['no ads'])",
        ),
    )

    # Add views_config and filters_config to prompts (AI-transformed)
    op.add_column(
        "prompts",
        sa.Column(
            "views_config",
            JSONB(),
            server_default="[]",
            nullable=False,
            comment="AI-transformed view configs: [{name, prompt}]",
        ),
    )
    op.add_column(
        "prompts",
        sa.Column(
            "filters_config",
            JSONB(),
            server_default="[]",
            nullable=False,
            comment="AI-transformed filter configs: [{name, prompt}]",
        ),
    )


def downgrade() -> None:
    op.drop_column("prompts", "filters_config")
    op.drop_column("prompts", "views_config")
    op.drop_column("pre_prompts", "filters_raw")
    op.drop_column("pre_prompts", "views_raw")
