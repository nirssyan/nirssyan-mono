"""Migrate tg:// URLs to tg/ for Traefik v3 compatibility.

Revision ID: 236389197a9c
Revises: 69af56181077
Create Date: 2026-02-02 12:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

revision: str = "236389197a9c"
down_revision: str | None = "37f4200cd354"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # posts.image_url: replace encoded tg%3A%2F%2F with tg%2F
    op.execute("""
        UPDATE posts
        SET image_url = REPLACE(image_url, 'tg%3A%2F%2F', 'tg%2F')
        WHERE image_url LIKE '%tg%3A%2F%2F%'
    """)

    op.execute("""
        UPDATE posts
        SET media_objects = (
            REPLACE(media_objects::text, 'tg%3A%2F%2F', 'tg%2F')
        )::jsonb
        WHERE media_objects IS NOT NULL
          AND media_objects::text LIKE '%tg%3A%2F%2F%'
    """)

    # raw_posts.media_objects
    op.execute("""
        UPDATE raw_posts
        SET media_objects = (
            REPLACE(media_objects::text, 'tg%3A%2F%2F', 'tg%2F')
        )::jsonb
        WHERE media_objects IS NOT NULL
          AND media_objects::text LIKE '%tg%3A%2F%2F%'
    """)


def downgrade() -> None:
    op.execute("""
        UPDATE posts
        SET image_url = REPLACE(image_url, 'tg%2F', 'tg%3A%2F%2F')
        WHERE image_url LIKE '%tg%2F%'
    """)

    op.execute("""
        UPDATE posts
        SET media_objects = (
            REPLACE(media_objects::text, 'tg%2F', 'tg%3A%2F%2F')
        )::jsonb
        WHERE media_objects IS NOT NULL
          AND media_objects::text LIKE '%tg%2F%'
    """)

    op.execute("""
        UPDATE raw_posts
        SET media_objects = (
            REPLACE(media_objects::text, 'tg%2F', 'tg%3A%2F%2F')
        )::jsonb
        WHERE media_objects IS NOT NULL
          AND media_objects::text LIKE '%tg%2F%'
    """)
