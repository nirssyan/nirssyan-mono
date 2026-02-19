from agno.run import RunContext
from agno.tools import tool

from agno_assistant.tools._http import api_call


@tool
def validate_source(run_context: RunContext, url: str, source_type: str) -> str:
    """Validate a source before adding it to a feed. Returns source info (title, description, post count).

    Args:
        url: Source URL (e.g. https://t.me/channel, RSS URL, or website URL).
        source_type: One of: telegram, rss, website.
    """
    return api_call(
        "POST",
        "/internal/sources/validate",
        run_context.user_id,
        json={"url": url, "type": source_type},
    )


@tool
def get_view_suggestions(run_context: RunContext) -> str:
    """Get available view types for feeds (e.g. summary, tldr, original)."""
    return api_call("GET", "/internal/suggestions/views", run_context.user_id)


@tool
def get_filter_suggestions(run_context: RunContext) -> str:
    """Get available filter presets for feeds."""
    return api_call("GET", "/internal/suggestions/filters", run_context.user_id)


@tool
def get_source_suggestions(run_context: RunContext) -> str:
    """Get popular source suggestions for discovering new content."""
    return api_call("GET", "/internal/suggestions/sources", run_context.user_id)
