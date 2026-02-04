"""sync_enums_and_tables

Revision ID: d4be2b23f519
Revises: 2245519270ed
Create Date: 2025-10-05 15:02:37.279402

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d4be2b23f519"
down_revision: str | None = "2245519270ed"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Synchronize enums and tables between databases.

    This migration ensures both databases have:
    - raw_type enum (RSS, TELEGRAM)
    - FeedTypeEnum with TELEGRAM value
    - wrappers_fdw_stats table (optional, only in development)

    All operations are idempotent.
    """

    # 1. Create raw_type enum if it doesn't exist
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'raw_type') THEN
                CREATE TYPE raw_type AS ENUM ('RSS', 'TELEGRAM');
            END IF;
        END $$;
        """
    )

    # 2. Add TELEGRAM to FeedTypeEnum if it doesn't exist
    # Note: ALTER TYPE ADD VALUE cannot be run inside a transaction block in PostgreSQL < 12
    # For newer versions, we use IF NOT EXISTS check
    op.execute(
        """
        DO $$
        BEGIN
            -- Check if TELEGRAM value exists
            IF NOT EXISTS (
                SELECT 1 FROM pg_enum
                WHERE enumtypid = '"FeedTypeEnum"'::regtype
                AND enumlabel = 'TELEGRAM'
            ) THEN
                -- Add TELEGRAM value
                ALTER TYPE "FeedTypeEnum" ADD VALUE 'TELEGRAM';
            END IF;
        EXCEPTION
            WHEN insufficient_privilege THEN
                -- If we don't have permission, skip silently
                -- This might happen if running as non-owner user
                RAISE NOTICE 'Skipping FeedTypeEnum modification due to insufficient privileges';
        END $$;
        """
    )

    # 3. Create wrappers_fdw_stats table if it doesn't exist (development feature)
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_name = 'wrappers_fdw_stats'
            ) THEN
                CREATE TABLE wrappers_fdw_stats (
                    fdw_name TEXT PRIMARY KEY NOT NULL,
                    create_times BIGINT,
                    rows_in BIGINT,
                    rows_out BIGINT,
                    bytes_in BIGINT,
                    bytes_out BIGINT,
                    metadata JSONB,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
                );
                COMMENT ON TABLE wrappers_fdw_stats IS 'Wrappers Foreign Data Wrapper statistics';
                COMMENT ON COLUMN wrappers_fdw_stats.create_times IS 'Total number of times the FDW instacne has been created';
                COMMENT ON COLUMN wrappers_fdw_stats.rows_in IS 'Total rows input from origin';
                COMMENT ON COLUMN wrappers_fdw_stats.rows_out IS 'Total rows output to Postgres';
                COMMENT ON COLUMN wrappers_fdw_stats.bytes_in IS 'Total bytes input from origin';
                COMMENT ON COLUMN wrappers_fdw_stats.bytes_out IS 'Total bytes output to Postgres';
                COMMENT ON COLUMN wrappers_fdw_stats.metadata IS 'Metadata specific for the FDW';
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    """Downgrade database changes.

    Note: Removing enum values is complex and potentially dangerous,
    so we only drop the table.
    """
    # Drop wrappers_fdw_stats table
    op.execute("DROP TABLE IF EXISTS wrappers_fdw_stats")

    # Note: We don't remove enum values or types as they might be in use
    # and PostgreSQL doesn't support removing enum values easily
