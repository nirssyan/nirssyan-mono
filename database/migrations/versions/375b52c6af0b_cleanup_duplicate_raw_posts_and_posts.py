"""cleanup_duplicate_raw_posts_and_posts

Revision ID: 375b52c6af0b
Revises: 0efb2351c36a
Create Date: 2026-01-11 00:01:43.598111

This migration cleans up:
1. Duplicate raw_posts created with tg_None_ unique codes
2. Duplicate posts created from the same source_url
3. Posts with title='Message' that have no meaningful content

Root cause: raw_posts were created with telegram_chat_id=None,
resulting in unique codes like 'tg_None_50840' that bypassed deduplication.
"""

from alembic import op

revision: str = "375b52c6af0b"
down_revision: str | None = "0efb2351c36a"
branch_labels: tuple[str, ...] | None = None
depends_on: tuple[str, ...] | None = None


def upgrade() -> None:
    # Step 1: Delete ALL raw_posts with tg_None_ unique codes
    # These are duplicates created due to missing telegram_chat_id
    # The proper versions with correct chat_id already exist or will be re-synced
    op.execute("""
        DELETE FROM raw_posts
        WHERE rp_unique_code LIKE 'tg_None_%'
    """)

    # Step 3: Delete duplicate sources (keeping oldest by id)
    # When same source_url appears multiple times in the same feed
    op.execute("""
        DELETE FROM sources
        WHERE id IN (
            SELECT s2.id
            FROM sources s1
            JOIN sources s2 ON s1.source_url = s2.source_url AND s1.id < s2.id
            JOIN posts p1 ON s1.post_id = p1.id
            JOIN posts p2 ON s2.post_id = p2.id
            WHERE p1.feed_id = p2.feed_id
        )
    """)

    # Step 4: Delete orphaned posts (posts without any sources)
    op.execute("""
        DELETE FROM posts
        WHERE id NOT IN (SELECT post_id FROM sources WHERE post_id IS NOT NULL)
    """)


def downgrade() -> None:
    # This is a data cleanup migration - not reversible
    # The deleted data cannot be recovered
    pass
