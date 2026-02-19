from agno.run import RunContext
from agno.tools import tool

from agno_assistant.tools._http import api_call


@tool
def list_feeds(run_context: RunContext) -> str:
    """List all feeds for the current user. Returns feed names, types, source counts and unread counts."""
    return api_call("GET", "/internal/feeds", run_context.user_id)


@tool
def create_feed(
    run_context: RunContext,
    name: str,
    sources: list[dict],
    views_raw: list[str],
    feed_type: str = "SINGLE_POST",
    filters_raw: list[str] | None = None,
) -> str:
    """Create a new feed.

    Args:
        name: Feed name.
        sources: List of sources, each with 'url' and 'type' (telegram/rss/website).
        views_raw: Required list of view types like ["summary"], ["tldr"], ["original"].
        feed_type: SINGLE_POST (default) or DIGEST.
        filters_raw: Optional list of filter descriptions.
    """
    body: dict = {
        "name": name,
        "feed_type": feed_type,
        "sources": sources,
        "views_raw": views_raw,
    }
    if filters_raw:
        body["filters_raw"] = filters_raw
    return api_call("POST", "/internal/feeds/create", run_context.user_id, json=body)


@tool
def update_feed(
    run_context: RunContext,
    feed_id: str,
    name: str | None = None,
    sources: list[dict] | None = None,
    views_raw: list[str] | None = None,
    filters_raw: list[str] | None = None,
) -> str:
    """Update an existing feed. Only provided fields are updated.

    Args:
        feed_id: UUID of the feed to update.
        name: New feed name.
        sources: New list of sources.
        views_raw: New list of view types.
        filters_raw: New list of filter descriptions.
    """
    body: dict = {}
    if name is not None:
        body["name"] = name
    if sources is not None:
        body["sources"] = sources
    if views_raw is not None:
        body["views_raw"] = views_raw
    if filters_raw is not None:
        body["filters_raw"] = filters_raw
    return api_call(
        "PATCH", f"/internal/feeds/{feed_id}", run_context.user_id, json=body
    )


@tool
def delete_feed(run_context: RunContext, feed_id: str) -> str:
    """Delete a feed.

    Args:
        feed_id: UUID of the feed to delete.
    """
    return api_call(
        "DELETE",
        "/internal/users_feeds",
        run_context.user_id,
        json={"feed_id": feed_id},
    )


@tool
def get_feed_posts(
    run_context: RunContext,
    feed_id: str,
    limit: int = 20,
    offset: int = 0,
) -> str:
    """Get posts from a feed.

    Args:
        feed_id: UUID of the feed.
        limit: Max number of posts to return (default 20).
        offset: Pagination offset (default 0).
    """
    return api_call(
        "GET",
        f"/internal/posts/feed/{feed_id}",
        run_context.user_id,
        params={"limit": limit, "offset": offset},
    )


@tool
def read_all_posts(run_context: RunContext, feed_id: str) -> str:
    """Mark all posts in a feed as read.

    Args:
        feed_id: UUID of the feed.
    """
    return api_call(
        "POST", f"/internal/feeds/read_all/{feed_id}", run_context.user_id
    )


@tool
def summarize_unseen(run_context: RunContext, feed_id: str) -> str:
    """Get a summary of unread posts in a feed.

    Args:
        feed_id: UUID of the feed.
    """
    return api_call(
        "POST", f"/internal/feeds/summarize_unseen/{feed_id}", run_context.user_id
    )


@tool
def rename_feed(run_context: RunContext, feed_id: str, name: str) -> str:
    """Rename a feed.

    Args:
        feed_id: UUID of the feed.
        name: New name for the feed.
    """
    return api_call(
        "POST",
        "/internal/feeds/rename",
        run_context.user_id,
        json={"feed_id": feed_id, "name": name},
    )


@tool
def generate_title(run_context: RunContext, feed_id: str) -> str:
    """Auto-generate a title for a feed based on its sources.

    Args:
        feed_id: UUID of the feed.
    """
    return api_call(
        "POST",
        "/internal/feeds/generate_title",
        run_context.user_id,
        json={"feed_id": feed_id},
    )
