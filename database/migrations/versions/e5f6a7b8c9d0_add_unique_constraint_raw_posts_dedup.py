"""Add UNIQUE constraint on raw_posts.rp_unique_code and clean up duplicate posts.

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-02-11 18:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "e5f6a7b8c9d0"
down_revision: str | None = "d4e5f6a7b8c9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("""
        DELETE FROM raw_posts
        WHERE id NOT IN (
            SELECT MIN(id::text)::uuid FROM raw_posts GROUP BY rp_unique_code
        )
    """)

    op.execute("""
        DELETE FROM posts
        WHERE id IN (
            SELECT p.id FROM posts p
            LEFT JOIN sources s ON s.post_id = p.id
            WHERE s.id IS NULL
            AND EXISTS (
                SELECT 1 FROM posts p2
                JOIN sources s2 ON s2.post_id = p2.id
                WHERE p2.feed_id = p.feed_id
                AND p2.created_at = p.created_at
                AND p2.id != p.id
            )
        )
    """)

    op.create_primary_key("pk_raw_posts", "raw_posts", ["id"])

    op.create_unique_constraint(
        "uq_raw_posts_unique_code", "raw_posts", ["rp_unique_code"]
    )


def downgrade() -> None:
    op.drop_constraint("uq_raw_posts_unique_code", "raw_posts", type_="unique")
    op.drop_constraint("pk_raw_posts", "raw_posts", type_="primary")
