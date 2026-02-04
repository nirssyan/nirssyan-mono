"""migrate_media_urls_to_media_objects

Revision ID: 2b26b4ad5828
Revises: 764aef5b7dd5
Create Date: 2025-10-06 12:09:53.465141

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2b26b4ad5828"
down_revision: str | None = "764aef5b7dd5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Migrate media_urls/image_urls arrays to media_objects JSONB."""

    # 1. Add new media_objects column to posts table
    op.add_column(
        "posts",
        sa.Column(
            "media_objects",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )

    # 2. Migrate existing posts.media_urls to posts.media_objects
    op.execute("""
        UPDATE posts
        SET media_objects = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN url LIKE '%tg://photo/%' OR url LIKE '%tg%3A%2F%2Fphoto%' THEN
                            jsonb_build_object(
                                'type', 'photo',
                                'url', url,
                                'mime_type', 'image/jpeg'
                            )
                        WHEN url LIKE '%tg://video/%' OR url LIKE '%tg%3A%2F%2Fvideo%' THEN
                            jsonb_build_object(
                                'type', 'video',
                                'url', url,
                                'preview_url', url,
                                'mime_type', 'video/mp4'
                            )
                        WHEN url LIKE '%tg://animation/%' OR url LIKE '%tg%3A%2F%2Fanimation%' THEN
                            jsonb_build_object(
                                'type', 'animation',
                                'url', url,
                                'mime_type', 'video/mp4'
                            )
                        WHEN url LIKE '%tg://document/%' OR url LIKE '%tg%3A%2F%2Fdocument%' THEN
                            jsonb_build_object(
                                'type', 'document',
                                'url', url,
                                'mime_type', 'application/octet-stream'
                            )
                        ELSE
                            jsonb_build_object(
                                'type', 'photo',
                                'url', url,
                                'mime_type', 'image/jpeg'
                            )
                    END
                ),
                '[]'::jsonb
            )
            FROM unnest(COALESCE(media_urls, ARRAY[]::text[])) AS url
        )
        WHERE media_urls IS NOT NULL
    """)

    # 3. Drop old media_urls column from posts
    op.drop_column("posts", "media_urls")

    # 4. Add new media_objects column to raw_posts table
    op.add_column(
        "raw_posts",
        sa.Column(
            "media_objects",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )

    # 5. Migrate existing raw_posts.image_urls to raw_posts.media_objects
    op.execute("""
        UPDATE raw_posts
        SET media_objects = (
            SELECT COALESCE(
                jsonb_agg(
                    CASE
                        WHEN url LIKE '%tg://photo/%' OR url LIKE '%tg%3A%2F%2Fphoto%' THEN
                            jsonb_build_object(
                                'type', 'photo',
                                'url', url,
                                'mime_type', 'image/jpeg'
                            )
                        WHEN url LIKE '%tg://video/%' OR url LIKE '%tg%3A%2F%2Fvideo%' THEN
                            jsonb_build_object(
                                'type', 'video',
                                'url', url,
                                'preview_url', url,
                                'mime_type', 'video/mp4'
                            )
                        WHEN url LIKE '%tg://animation/%' OR url LIKE '%tg%3A%2F%2Fanimation%' THEN
                            jsonb_build_object(
                                'type', 'animation',
                                'url', url,
                                'mime_type', 'video/mp4'
                            )
                        WHEN url LIKE '%tg://document/%' OR url LIKE '%tg%3A%2F%2Fdocument%' THEN
                            jsonb_build_object(
                                'type', 'document',
                                'url', url,
                                'mime_type', 'application/octet-stream'
                            )
                        ELSE
                            jsonb_build_object(
                                'type', 'photo',
                                'url', url,
                                'mime_type', 'image/jpeg'
                            )
                    END
                ),
                '[]'::jsonb
            )
            FROM unnest(COALESCE(image_urls, ARRAY[]::text[])) AS url
        )
        WHERE image_urls IS NOT NULL
    """)

    # 6. Drop old image_urls column from raw_posts
    op.drop_column("raw_posts", "image_urls")


def downgrade() -> None:
    """Rollback media_objects JSONB to media_urls/image_urls arrays."""

    # 1. Add back media_urls column to posts
    op.add_column(
        "posts",
        sa.Column("media_urls", sa.ARRAY(sa.Text()), nullable=True),
    )

    # 2. Migrate posts.media_objects back to posts.media_urls
    op.execute("""
        UPDATE posts
        SET media_urls = (
            SELECT array_agg(obj->>'url')
            FROM jsonb_array_elements(COALESCE(media_objects, '[]'::jsonb)) AS obj
        )
        WHERE media_objects IS NOT NULL AND media_objects != '[]'::jsonb
    """)

    # 3. Drop media_objects column from posts
    op.drop_column("posts", "media_objects")

    # 4. Add back image_urls column to raw_posts
    op.add_column(
        "raw_posts",
        sa.Column(
            "image_urls",
            sa.ARRAY(sa.Text()),
            nullable=False,
            server_default=sa.text("ARRAY[]::text[]"),
        ),
    )

    # 5. Migrate raw_posts.media_objects back to raw_posts.image_urls
    op.execute("""
        UPDATE raw_posts
        SET image_urls = (
            SELECT COALESCE(array_agg(obj->>'url'), ARRAY[]::text[])
            FROM jsonb_array_elements(COALESCE(media_objects, '[]'::jsonb)) AS obj
        )
        WHERE media_objects IS NOT NULL AND media_objects != '[]'::jsonb
    """)

    # 6. Drop media_objects column from raw_posts
    op.drop_column("raw_posts", "media_objects")
