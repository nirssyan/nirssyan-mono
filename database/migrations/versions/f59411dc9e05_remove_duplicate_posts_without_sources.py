"""remove_duplicate_posts_without_sources

Revision ID: f59411dc9e05
Revises: 94c17776769e
Create Date: 2026-01-08 12:55:31.088182

This migration removes duplicate posts that were created due to a race condition
between initial_sync and regular processing. The duplicates are identified as:
- Posts WITHOUT a source_url (no entry in sources table)
- That have a matching post WITH source_url (has entry in sources table)
- With the same title in the same feed

Only affects feed "Бизнес Новости" (1822e5b2-4413-40f3-a4c8-fea15ce9b4bd).
"""

from collections.abc import Sequence

from alembic import op

revision: str = "f59411dc9e05"
down_revision: str | None = "94c17776769e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FEED_ID = "1822e5b2-4413-40f3-a4c8-fea15ce9b4bd"


def upgrade() -> None:
    op.execute(f"""
        DELETE FROM posts p1
        WHERE p1.feed_id = '{FEED_ID}'
          AND NOT EXISTS (SELECT 1 FROM sources s WHERE s.post_id = p1.id)
          AND EXISTS (
            SELECT 1 FROM posts p2
            JOIN sources s ON s.post_id = p2.id
            WHERE p2.feed_id = p1.feed_id
              AND p2.title = p1.title
              AND p2.id != p1.id
          )
    """)


def downgrade() -> None:
    pass
