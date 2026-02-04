"""create_local_auth_users_table

Revision ID: 71604c17ece4
Revises: d84627b18361
Create Date: 2025-10-05 20:35:31.730875

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "71604c17ece4"
down_revision: str | None = "d84627b18361"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create auth.users table only in local environment.

    This migration checks if the auth schema exists (production).
    If it doesn't exist, creates the schema and table (local dev).
    Production databases already have this table from Supabase.
    """
    op.execute("""
        DO $$
        BEGIN
            -- Check if auth schema exists using pg_namespace (more reliable than information_schema)
            IF NOT EXISTS (
                SELECT 1 FROM pg_namespace WHERE nspname = 'auth'
            ) THEN
                -- Create auth schema for local development
                CREATE SCHEMA IF NOT EXISTS auth;

                -- Create minimal auth.users table for local development
                CREATE TABLE IF NOT EXISTS auth.users (
                    id UUID PRIMARY KEY,
                    email VARCHAR(255),
                    raw_user_meta_data JSONB
                );

                -- Insert existing users from chats and users_feeds
                INSERT INTO auth.users (id, email, raw_user_meta_data)
                SELECT DISTINCT user_id, NULL::VARCHAR(255), NULL::JSONB
                FROM (
                    SELECT user_id FROM chats
                    UNION
                    SELECT user_id FROM users_feeds
                ) AS existing_users
                ON CONFLICT (id) DO NOTHING;

                -- Add foreign key constraints that reference auth.users
                -- These constraints are removed in tests but exist in production
                ALTER TABLE chats
                ADD CONSTRAINT chats_user_id_fkey
                FOREIGN KEY (user_id) REFERENCES auth.users(id)
                ON UPDATE CASCADE;

                ALTER TABLE users_feeds
                ADD CONSTRAINT users_feeds_user_id_fkey
                FOREIGN KEY (user_id) REFERENCES auth.users(id)
                ON UPDATE CASCADE
                ON DELETE CASCADE;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    """Remove auth.users table only if it was created by this migration.

    Only drops the table if we're in local environment (auth schema has only users table).
    """
    op.execute("""
        DO $$
        BEGIN
            -- Only drop if auth schema exists and contains just our test table
            IF EXISTS (
                SELECT 1 FROM pg_namespace WHERE nspname = 'auth'
            ) THEN
                -- Check if this looks like our local test schema (has only users table)
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.tables
                    WHERE table_schema = 'auth'
                    AND table_name NOT IN ('users')
                ) THEN
                    -- Safe to drop - this is local environment
                    DROP TABLE IF EXISTS auth.users CASCADE;
                    DROP SCHEMA IF EXISTS auth CASCADE;
                END IF;
            END IF;
        END $$;
    """)
