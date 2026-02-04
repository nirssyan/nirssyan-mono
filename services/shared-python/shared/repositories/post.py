"""Post repository for database operations."""

import base64
import json
from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import func, insert, select, text
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import posts, posts_seen, sources


def encode_cursor(created_at: datetime, id: UUID) -> str:
    """Encode created_at and id into a base64 cursor.

    Args:
        created_at: Post creation timestamp
        id: Post UUID

    Returns:
        Base64 encoded JSON string
    """
    data = {"created_at": created_at.isoformat(), "id": str(id)}
    return base64.b64encode(json.dumps(data).encode()).decode()


def decode_cursor(cursor: str) -> tuple[datetime, UUID]:
    """Decode a base64 cursor into created_at and id.

    Args:
        cursor: Base64 encoded JSON string

    Returns:
        Tuple of (datetime, UUID)

    Raises:
        ValueError: If cursor is invalid
    """
    try:
        decoded = base64.b64decode(cursor).decode()
        data = json.loads(decoded)
        return datetime.fromisoformat(data["created_at"]), UUID(data["id"])
    except Exception as e:
        raise ValueError(f"Invalid cursor: {str(e)}") from e


def get_image_url_from_media_objects(
    media_objects: list[dict[str, Any]] | None,
) -> str | None:
    """Extract the best image URL from media_objects.

    For videos, uses preview_url (thumbnail) instead of url (video file).
    For photos and other types, uses url directly.

    Args:
        media_objects: List of media object dictionaries

    Returns:
        Image URL string or None if no suitable URL found
    """
    if not media_objects:
        return None

    first_media = media_objects[0]

    # Handle malformed data: skip if element is not a dict
    if not isinstance(first_media, dict):
        return None

    media_type = first_media.get("media_type", "")

    # For videos, prefer preview_url (thumbnail) over url (video file)
    if media_type == "video":
        preview_url = first_media.get("preview_url")
        if preview_url:
            return preview_url

    # For photos and fallback, use url
    return first_media.get("url")


def _infer_mime_type_from_url(url: str) -> str:
    """Infer MIME type from URL extension."""
    url_lower = url.lower()
    if any(ext in url_lower for ext in [".jpg", ".jpeg"]):
        return "image/jpeg"
    if ".png" in url_lower:
        return "image/png"
    if ".webp" in url_lower:
        return "image/webp"
    if ".gif" in url_lower:
        return "image/gif"
    if ".mp4" in url_lower:
        return "video/mp4"
    if ".webm" in url_lower:
        return "video/webm"
    if ".pdf" in url_lower:
        return "application/pdf"
    return "application/octet-stream"


def _infer_media_type_from_url(url: str) -> str:
    """Infer media type (photo/video) from URL extension."""
    url_lower = url.lower()
    if any(ext in url_lower for ext in [".mp4", ".webm", ".mov", ".avi"]):
        return "video"
    if ".gif" in url_lower:
        return "animation"
    if ".pdf" in url_lower:
        return "document"
    return "photo"


def _normalize_media_objects(media_objects: list | None) -> list[dict]:
    """Normalize media_objects to ensure all items are proper dicts.

    Handles cases where media_objects contains plain string URLs instead of dicts.
    Converts strings to proper media object format with type, url, and mime_type.

    Args:
        media_objects: List of media objects (dicts or strings)

    Returns:
        List of normalized media object dicts
    """
    if not media_objects:
        return []

    normalized = []
    for item in media_objects:
        if isinstance(item, dict):
            normalized.append(item)
        elif isinstance(item, str):
            media_type = _infer_media_type_from_url(item)
            mime_type = _infer_mime_type_from_url(item)
            media_obj: dict = {
                "type": media_type,
                "url": item,
                "mime_type": mime_type,
            }
            if media_type == "video":
                media_obj["preview_url"] = item
            normalized.append(media_obj)
    return normalized


def adapt_post_to_v1(post: dict) -> dict:
    """Adapt post with views to v1 API format (full_text/summary).

    Priority for summary: summary > ai_generation > overview (backward compatibility).
    Also normalizes media_objects to ensure proper dict format.

    Args:
        post: Post dict with views JSONB field

    Returns:
        Post dict with full_text and summary fields (v1 format)
    """
    views = post.get("views", {})
    summary = (
        views.get("summary") or views.get("ai_generation") or views.get("overview")
    )
    return {
        **post,
        "full_text": views.get("full_text", ""),
        "summary": summary,
        "media_objects": _normalize_media_objects(post.get("media_objects")),
    }


class PostRepository:
    """Repository for post-related database operations."""

    async def create_post(
        self,
        conn: AsyncConnection,
        feed_id: UUID,
        views: dict,
        title: str | None = None,
        image_url: str | None = None,
        media_objects: list[dict[str, Any]] | None = None,
        created_at: datetime | None = None,
        moderation_action: str | None = None,
        moderation_labels: list[str] | None = None,
        moderation_matched_entities: list[str] | None = None,
    ) -> dict[str, Any]:
        """Create a new post with views JSONB.

        Args:
            conn: Database connection
            feed_id: ID of the feed this post belongs to
            views: JSONB dict containing different views (ai_generation, full_text, overview)
            title: Optional title of the post
            image_url: Optional URL of the post image (deprecated, use media_objects)
            media_objects: Optional list of media object dictionaries (JSON-serializable)
            created_at: Optional datetime for when the post was created (from raw_post)
            moderation_action: Moderation action (block, label, pass, review)
            moderation_labels: List of moderation labels (foreign_agent, extremist_org, etc.)
            moderation_matched_entities: List of matched entity names with * suffix

        Returns:
            Dictionary containing the created post data
        """
        if media_objects and not image_url:
            image_url = get_image_url_from_media_objects(media_objects)

        values = {
            "feed_id": feed_id,
            "views": views,
            "title": title,
            "image_url": image_url,
            "media_objects": media_objects or [],
            "moderation_action": moderation_action,
            "moderation_labels": moderation_labels or [],
            "moderation_matched_entities": moderation_matched_entities or [],
        }

        if created_at is not None:
            values["created_at"] = created_at

        query = insert(posts).values(**values).returning(posts)
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to create post")
        return dict(row._mapping)

    async def batch_create_posts(
        self,
        conn: AsyncConnection,
        posts_data: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """Create multiple posts in a single batch operation.

        Optimized for creating multiple posts in a single query instead of N queries.

        Args:
            conn: Database connection
            posts_data: List of dictionaries with post data. Each dict must contain:
                - feed_id: UUID
                - views: dict (JSONB with full_text, ai_generation, etc.)
                - title: Optional[str]
                - media_objects: Optional[List[Dict]]
                - created_at: Optional[datetime]
                - moderation_action: Optional[str] (block, label, pass, review)
                - moderation_labels: Optional[List[str]] (foreign_agent, extremist_org, etc.)
                - moderation_matched_entities: Optional[List[str]] (matched names with *)

        Returns:
            List of created post dictionaries with their IDs

        Raises:
            ValueError: If no posts were created
        """
        if not posts_data:
            return []

        values_list = []
        for post in posts_data:
            media_objects = post.get("media_objects") or []
            image_url = post.get("image_url")
            if media_objects and not image_url:
                image_url = get_image_url_from_media_objects(media_objects)

            values = {
                "feed_id": post["feed_id"],
                "views": post["views"],
                "title": post.get("title"),
                "image_url": image_url,
                "media_objects": media_objects,
                "moderation_action": post.get("moderation_action"),
                "moderation_labels": post.get("moderation_labels") or [],
                "moderation_matched_entities": post.get("moderation_matched_entities")
                or [],
            }

            if "created_at" in post and post["created_at"] is not None:
                values["created_at"] = post["created_at"]

            values_list.append(values)

        query = insert(posts).values(values_list).returning(posts)
        result = await conn.execute(query)
        rows = result.fetchall()

        if not rows:
            raise ValueError(f"Failed to create {len(posts_data)} posts")

        return [dict(row._mapping) for row in rows]

    async def get_post_by_id(
        self, conn: AsyncConnection, post_id: UUID
    ) -> dict[str, Any] | None:
        """Get a post by ID with associated sources.

        Args:
            conn: Database connection
            post_id: ID of the post to retrieve

        Returns:
            Dictionary containing post data with sources list, or None if not found
        """
        # Get post data
        post_query = select(posts).where(posts.c.id == post_id)
        post_result = await conn.execute(post_query)
        post_row = post_result.fetchone()

        if post_row is None:
            return None

        # Get associated sources
        sources_query = select(sources).where(sources.c.post_id == post_id)
        sources_result = await conn.execute(sources_query)
        sources_rows = sources_result.fetchall()

        # Build response with sources
        post_data = dict(post_row._mapping)
        post_data["sources"] = [dict(row._mapping) for row in sources_rows]

        return post_data

    async def get_unseen_posts_for_feed(
        self,
        conn: AsyncConnection,
        feed_id: UUID,
        user_id: UUID,
    ) -> list[dict[str, Any]]:
        """Get posts for feed that user hasn't seen yet.

        Args:
            conn: Database connection
            feed_id: ID of the feed
            user_id: ID of the user

        Returns:
            List of unseen post dictionaries with id, title, views, etc.
        """
        query = (
            select(posts)
            .outerjoin(
                posts_seen,
                (posts.c.id == posts_seen.c.post_id)
                & (posts_seen.c.user_id == user_id),
            )
            .where(
                (posts.c.feed_id == feed_id)
                & (
                    (posts_seen.c.id == None)  # noqa: E711
                    | (posts_seen.c.seen == False)  # noqa: E712
                )
            )
            .order_by(posts.c.created_at.asc())
        )

        result = await conn.execute(query)
        rows = result.fetchall()
        return [dict(row._mapping) for row in rows]

    async def get_feed_posts_paginated(
        self,
        conn: AsyncConnection,
        feed_id: UUID,
        user_id: UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> dict[str, Any]:
        """Get posts for a feed with cursor-based pagination.

        Args:
            conn: Database connection
            feed_id: ID of the feed
            user_id: ID of the user (for 'seen' status)
            limit: Number of posts to return
            cursor: Base64 encoded JSON string with created_at and id

        Returns:
            Dictionary with posts, next_cursor, has_more, and total_count
        """
        # Get total count
        count_query = (
            select(func.count()).select_from(posts).where(posts.c.feed_id == feed_id)
        )
        count_result = await conn.execute(count_query)
        total_count = int(count_result.scalar() or 0)

        # Base query
        query_str = """
            SELECT
                posts.id,
                posts.created_at,
                posts.feed_id,
                posts.views,
                posts.media_objects,
                posts.title,
                posts.moderation_action,
                posts.moderation_labels,
                posts.moderation_matched_entities,
                COALESCE(posts_seen.seen, false) as seen,
                (
                    SELECT COALESCE(
                        json_agg(
                            jsonb_build_object(
                                'id', sources.id,
                                'created_at', sources.created_at,
                                'post_id', sources.post_id,
                                'source_url', sources.source_url
                            )
                        ),
                        '[]'::json
                    )
                    FROM sources
                    WHERE sources.post_id = posts.id
                ) as sources
            FROM posts
            LEFT JOIN posts_seen ON posts.id = posts_seen.post_id AND posts_seen.user_id = :user_id
            WHERE posts.feed_id = :feed_id
        """

        params = {"user_id": user_id, "feed_id": feed_id, "limit": limit + 1}

        if cursor:
            cursor_created_at, cursor_id = decode_cursor(cursor)
            query_str += (
                " AND (posts.created_at, posts.id) < (:cursor_created_at, :cursor_id)"
            )
            params["cursor_created_at"] = cursor_created_at
            params["cursor_id"] = cursor_id

        query_str += " ORDER BY posts.created_at DESC, posts.id DESC LIMIT :limit"

        result = await conn.execute(text(query_str), params)
        rows = result.fetchall()

        posts_data = [dict(row._mapping) for row in rows]

        has_more = len(posts_data) > limit
        next_cursor = None
        if has_more:
            posts_data = posts_data[:limit]
            last_post = posts_data[-1]
            next_cursor = encode_cursor(last_post["created_at"], last_post["id"])

        return {
            "posts": posts_data,
            "next_cursor": next_cursor,
            "has_more": has_more,
            "total_count": total_count,
        }

    async def count_posts_by_feed_id(
        self,
        conn: AsyncConnection,
        feed_id: UUID,
    ) -> int:
        """Count total posts in a feed.

        Args:
            conn: Database connection
            feed_id: ID of the feed

        Returns:
            Total number of posts in the feed
        """
        query = (
            select(func.count()).select_from(posts).where(posts.c.feed_id == feed_id)
        )
        result = await conn.execute(query)
        return int(result.scalar() or 0)
