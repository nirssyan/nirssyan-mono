"""add_feed_id_to_sources_unique_constraint

Revision ID: 4a8c92d1e7f3
Revises: 375b52c6af0b
Create Date: 2026-01-14 12:30:00.000000

This migration:
1. Adds feed_id column to sources table
2. Populates it from linked posts
3. Removes duplicate sources (keeping oldest)
4. Removes orphaned posts
5. Creates UNIQUE constraint on (feed_id, source_url)

Root cause: Race condition when multiple workers process same raw_post
in parallel - SELECT check passes for all, all INSERT.
Solution: Database-level UNIQUE constraint with ON CONFLICT DO NOTHING.
"""

import sqlalchemy as sa
from alembic import op

revision: str = "4a8c92d1e7f3"
down_revision: str | None = "375b52c6af0b"
branch_labels: tuple[str, ...] | None = None
depends_on: tuple[str, ...] | None = None


def upgrade() -> None:
    # Step 1: Add feed_id column (nullable initially)
    op.add_column("sources", sa.Column("feed_id", sa.UUID(), nullable=True))

    # Step 2: Populate feed_id from linked posts
    op.execute("""
        UPDATE sources s
        SET feed_id = p.feed_id
        FROM posts p
        WHERE s.post_id = p.id
    """)

    # Step 3: Delete sources where feed_id is still NULL (orphaned sources)
    op.execute("""
        DELETE FROM sources WHERE feed_id IS NULL
    """)

    # Step 4: Delete duplicate sources - keep oldest (smallest id) for each (feed_id, source_url)
    op.execute("""
        DELETE FROM sources s1
        USING sources s2
        WHERE s1.feed_id = s2.feed_id
          AND s1.source_url = s2.source_url
          AND s1.source_url IS NOT NULL
          AND s1.id > s2.id
    """)

    # Step 5: Delete orphaned posts (posts without sources)
    op.execute("""
        DELETE FROM posts
        WHERE id NOT IN (SELECT post_id FROM sources WHERE post_id IS NOT NULL)
    """)

    # Step 6: Make feed_id NOT NULL
    op.alter_column("sources", "feed_id", nullable=False)

    # Step 7: Create UNIQUE constraint
    op.create_unique_constraint(
        "uq_sources_feed_id_source_url", "sources", ["feed_id", "source_url"]
    )

    # Step 8: Add foreign key constraint
    op.create_foreign_key(
        "fk_sources_feed_id",
        "sources",
        "feeds",
        ["feed_id"],
        ["id"],
        ondelete="CASCADE",
    )

    # Step 9: Create index for faster lookups
    op.create_index(
        "ix_sources_feed_id_source_url", "sources", ["feed_id", "source_url"]
    )


def downgrade() -> None:
    op.drop_index("ix_sources_feed_id_source_url", table_name="sources")
    op.drop_constraint("fk_sources_feed_id", "sources", type_="foreignkey")
    op.drop_constraint("uq_sources_feed_id_source_url", "sources", type_="unique")
    op.drop_column("sources", "feed_id")
