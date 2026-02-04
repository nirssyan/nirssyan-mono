"""add_missing_telegram_columns

Revision ID: 2245519270ed
Revises: 769359ffd138
Create Date: 2025-10-05 14:51:30.452038

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2245519270ed"
down_revision: str | None = "769359ffd138"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add missing telegram columns to raw_feeds table.

    This migration is idempotent - it checks for column existence before adding.
    This allows it to work on both databases where columns may or may not exist.
    """
    # Check and add telegram_chat_id column
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'raw_feeds' AND column_name = 'telegram_chat_id'
            ) THEN
                ALTER TABLE raw_feeds ADD COLUMN telegram_chat_id BIGINT;
            END IF;
        END $$;
        """
    )

    # Check and add telegram_username column
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'raw_feeds' AND column_name = 'telegram_username'
            ) THEN
                ALTER TABLE raw_feeds ADD COLUMN telegram_username TEXT;
            END IF;
        END $$;
        """
    )

    # Check and add last_execution column
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'raw_feeds' AND column_name = 'last_execution'
            ) THEN
                ALTER TABLE raw_feeds ADD COLUMN last_execution TIMESTAMP WITH TIME ZONE;
            END IF;
        END $$;
        """
    )

    # Create index on telegram_username if it doesn't exist
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE tablename = 'raw_feeds' AND indexname = 'ix_raw_feeds_telegram_username'
            ) THEN
                CREATE INDEX ix_raw_feeds_telegram_username ON raw_feeds (telegram_username);
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    """Remove telegram columns from raw_feeds table."""
    # Drop index
    op.execute("DROP INDEX IF EXISTS ix_raw_feeds_telegram_username")

    # Drop columns
    op.execute("ALTER TABLE raw_feeds DROP COLUMN IF EXISTS telegram_chat_id")
    op.execute("ALTER TABLE raw_feeds DROP COLUMN IF EXISTS telegram_username")
    op.execute("ALTER TABLE raw_feeds DROP COLUMN IF EXISTS last_execution")
