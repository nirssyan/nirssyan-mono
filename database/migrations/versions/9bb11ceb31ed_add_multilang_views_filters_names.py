"""add_multilang_views_filters_names

Revision ID: 9bb11ceb31ed
Revises: 4a8c92d1e7f3
Create Date: 2026-01-16 12:36:48.563426

This migration:
1. Migrates existing views_config in prompts from {name: string} to {name: {en, ru}}
2. Migrates existing filters_config in prompts from {name: string} to {name: {en, ru}}
"""

from alembic import op

revision: str = "9bb11ceb31ed"
down_revision: str | None = "4a8c92d1e7f3"
branch_labels: None = None
depends_on: None = None


def upgrade() -> None:
    # Step 1: Migrate prompts.views_config from [{name: string, prompt}] to [{name: {en, ru}, prompt}]
    op.execute("""
        UPDATE prompts
        SET views_config = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN jsonb_typeof(elem->'name') = 'string' THEN
                            jsonb_build_object(
                                'name', jsonb_build_object('en', elem->>'name', 'ru', elem->>'name'),
                                'prompt', elem->>'prompt'
                            )
                        ELSE elem
                    END
                ),
                '[]'::jsonb
            )
            FROM jsonb_array_elements(views_config) elem
        )
        WHERE views_config != '[]'::jsonb
        AND views_config IS NOT NULL
        AND jsonb_typeof(views_config) = 'array'
    """)

    # Step 2: Migrate prompts.filters_config from [{name: string, prompt}] to [{name: {en, ru}, prompt}]
    op.execute("""
        UPDATE prompts
        SET filters_config = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN jsonb_typeof(elem->'name') = 'string' THEN
                            jsonb_build_object(
                                'name', jsonb_build_object('en', elem->>'name', 'ru', elem->>'name'),
                                'prompt', elem->>'prompt'
                            )
                        ELSE elem
                    END
                ),
                '[]'::jsonb
            )
            FROM jsonb_array_elements(filters_config) elem
        )
        WHERE filters_config != '[]'::jsonb
        AND filters_config IS NOT NULL
        AND jsonb_typeof(filters_config) = 'array'
    """)


def downgrade() -> None:
    # Step 1: Revert prompts.views_config from [{name: {en, ru}, prompt}] to [{name: string, prompt}]
    op.execute("""
        UPDATE prompts
        SET views_config = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN jsonb_typeof(elem->'name') = 'object' THEN
                            jsonb_build_object(
                                'name', elem->'name'->>'en',
                                'prompt', elem->>'prompt'
                            )
                        ELSE elem
                    END
                ),
                '[]'::jsonb
            )
            FROM jsonb_array_elements(views_config) elem
        )
        WHERE views_config != '[]'::jsonb
        AND views_config IS NOT NULL
        AND jsonb_typeof(views_config) = 'array'
    """)

    # Step 2: Revert prompts.filters_config from [{name: {en, ru}, prompt}] to [{name: string, prompt}]
    op.execute("""
        UPDATE prompts
        SET filters_config = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN jsonb_typeof(elem->'name') = 'object' THEN
                            jsonb_build_object(
                                'name', elem->'name'->>'en',
                                'prompt', elem->>'prompt'
                            )
                        ELSE elem
                    END
                ),
                '[]'::jsonb
            )
            FROM jsonb_array_elements(filters_config) elem
        )
        WHERE filters_config != '[]'::jsonb
        AND filters_config IS NOT NULL
        AND jsonb_typeof(filters_config) = 'array'
    """)
