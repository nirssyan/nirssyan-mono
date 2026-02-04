"""fix_raw_feeds_raw_type_column

Revision ID: 54a1db4c1ca9
Revises: d4be2b23f519
Create Date: 2025-10-05 15:15:00.000000

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "54a1db4c1ca9"
down_revision: str | None = "d4be2b23f519"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Fix raw_feeds.raw_type column to use raw_type enum instead of FeedTypeEnum.

    This migration ensures the column type matches the application code expectations.
    It's idempotent - checks current type before converting.
    """

    # Check current column type and convert if needed
    op.execute(
        """
        DO $$
        DECLARE
            current_type TEXT;
        BEGIN
            -- Get current enum type for raw_type column
            SELECT udt_name INTO current_type
            FROM information_schema.columns
            WHERE table_name = 'raw_feeds' AND column_name = 'raw_type';

            -- If column is using FeedTypeEnum, convert it to raw_type
            IF current_type = 'FeedTypeEnum' THEN
                -- Step 1: Convert to TEXT (intermediate step to avoid enum conflicts)
                ALTER TABLE raw_feeds ALTER COLUMN raw_type TYPE TEXT;

                -- Step 2: Convert from TEXT to raw_type enum
                ALTER TABLE raw_feeds ALTER COLUMN raw_type TYPE raw_type USING raw_type::raw_type;

                RAISE NOTICE 'Converted raw_feeds.raw_type from FeedTypeEnum to raw_type';
            ELSIF current_type = 'raw_type' THEN
                RAISE NOTICE 'raw_feeds.raw_type already uses raw_type enum';
            ELSE
                RAISE WARNING 'Unexpected type for raw_feeds.raw_type: %', current_type;
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    """Revert raw_feeds.raw_type to use FeedTypeEnum.

    Note: This downgrade is complex and potentially lossy if TELEGRAM values exist.
    Only execute if absolutely necessary.
    """
    op.execute(
        """
        DO $$
        BEGIN
            -- Convert raw_type back to FeedTypeEnum
            -- Step 1: TEXT intermediate
            ALTER TABLE raw_feeds ALTER COLUMN raw_type TYPE TEXT;

            -- Step 2: Convert to FeedTypeEnum
            ALTER TABLE raw_feeds ALTER COLUMN raw_type TYPE "FeedTypeEnum" USING raw_type::"FeedTypeEnum";

            RAISE NOTICE 'Reverted raw_feeds.raw_type to FeedTypeEnum';
        EXCEPTION
            WHEN others THEN
                RAISE WARNING 'Failed to revert raw_feeds.raw_type: %', SQLERRM;
        END $$;
        """
    )
