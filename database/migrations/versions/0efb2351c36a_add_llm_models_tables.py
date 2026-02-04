"""add llm_models tables

Revision ID: 0efb2351c36a
Revises: a1b2c3d4e5f6
Create Date: 2026-01-10 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "0efb2351c36a"
down_revision: str | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "llm_models",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "model_id",
            sa.String(200),
            nullable=False,
            unique=True,
            comment="OpenRouter model ID (e.g., google/gemini-3-flash-preview)",
        ),
        sa.Column(
            "provider",
            sa.String(100),
            nullable=False,
            comment="Model provider (e.g., google, anthropic, openai)",
        ),
        sa.Column(
            "name",
            sa.Text,
            nullable=False,
            comment="Human-readable model name",
        ),
        sa.Column(
            "model_created_at",
            sa.BigInteger,
            nullable=True,
            comment="Unix timestamp of model creation from OpenRouter API",
        ),
        sa.Column("context_length", sa.Integer, nullable=True),
        sa.Column(
            "input_modalities",
            JSONB,
            nullable=False,
            server_default=sa.text("'[\"text\"]'::jsonb"),
        ),
        sa.Column(
            "output_modalities",
            JSONB,
            nullable=False,
            server_default=sa.text("'[\"text\"]'::jsonb"),
        ),
        sa.Column(
            "price_prompt",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
            server_default="0",
            comment="Price per token for prompt/input (USD)",
        ),
        sa.Column(
            "price_completion",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
            server_default="0",
            comment="Price per token for completion/output (USD)",
        ),
        sa.Column(
            "price_image",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
            server_default="0",
            comment="Price per image (USD)",
        ),
        sa.Column(
            "price_audio",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
            server_default="0",
            comment="Price per audio second (USD)",
        ),
        sa.Column(
            "is_active",
            sa.Boolean,
            nullable=False,
            server_default=sa.true(),
            comment="Whether model is currently available",
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
        sa.Column(
            "prices_changed_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Timestamp of last price change",
        ),
        sa.Column(
            "last_synced_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("idx_llm_models_provider", "llm_models", ["provider"])
    op.create_index("idx_llm_models_created_at", "llm_models", ["created_at"])
    op.create_index("idx_llm_models_is_active", "llm_models", ["is_active"])

    op.create_table(
        "llm_model_price_history",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "model_id",
            sa.String(200),
            nullable=False,
            comment="OpenRouter model ID for reference",
        ),
        sa.Column(
            "llm_model_uuid",
            UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "prev_price_prompt",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
        ),
        sa.Column(
            "prev_price_completion",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
        ),
        sa.Column(
            "new_price_prompt",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
        ),
        sa.Column(
            "new_price_completion",
            sa.Numeric(precision=20, scale=12),
            nullable=False,
        ),
        sa.Column(
            "change_percent_prompt",
            sa.Numeric(precision=10, scale=4),
            nullable=True,
            comment="Percentage change for prompt price",
        ),
        sa.Column(
            "change_percent_completion",
            sa.Numeric(precision=10, scale=4),
            nullable=True,
            comment="Percentage change for completion price",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["llm_model_uuid"],
            ["llm_models.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "idx_llm_price_history_model_id",
        "llm_model_price_history",
        ["model_id"],
    )
    op.create_index(
        "idx_llm_price_history_created_at",
        "llm_model_price_history",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "idx_llm_price_history_created_at",
        table_name="llm_model_price_history",
    )
    op.drop_index(
        "idx_llm_price_history_model_id",
        table_name="llm_model_price_history",
    )
    op.drop_table("llm_model_price_history")
    op.drop_index("idx_llm_models_is_active", table_name="llm_models")
    op.drop_index("idx_llm_models_created_at", table_name="llm_models")
    op.drop_index("idx_llm_models_provider", table_name="llm_models")
    op.drop_table("llm_models")
