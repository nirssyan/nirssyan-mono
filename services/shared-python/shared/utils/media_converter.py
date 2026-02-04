"""Utility functions for converting media URLs to MediaObject format."""

from typing import Any


def convert_media_urls_to_objects(media_urls: list[str] | None) -> list[dict[str, Any]]:
    """Convert media_urls list to media_objects format.

    Args:
        media_urls: List of media URLs (strings)

    Returns:
        List of media objects in MediaObject-compatible format with
        type, url, and mime_type fields
    """
    if not media_urls:
        return []

    media_objects = []

    for url in media_urls:
        url_lower = url.lower()

        video_exts = [".mp4", ".webm", ".ogg", ".mov", ".avi", ".mkv"]
        is_video = any(url_lower.endswith(ext) for ext in video_exts)

        is_embedded = any(
            domain in url_lower
            for domain in [
                "youtube.com",
                "youtu.be",
                "vimeo.com",
                "dailymotion.com",
            ]
        )

        if is_video or is_embedded:
            mime_type = "video/mp4"
            if url_lower.endswith(".webm"):
                mime_type = "video/webm"
            elif url_lower.endswith(".ogg"):
                mime_type = "video/ogg"
            elif url_lower.endswith(".mov"):
                mime_type = "video/quicktime"
            elif url_lower.endswith(".avi"):
                mime_type = "video/x-msvideo"
            elif url_lower.endswith(".mkv"):
                mime_type = "video/x-matroska"

            media_objects.append(
                {
                    "type": "video",
                    "url": url,
                    "mime_type": mime_type,
                    "preview_url": url,
                    "width": None,
                    "height": None,
                    "duration": None,
                }
            )
        else:
            mime_type = "image/jpeg"
            if url_lower.endswith(".png"):
                mime_type = "image/png"
            elif url_lower.endswith(".gif"):
                mime_type = "image/gif"
            elif url_lower.endswith(".webp"):
                mime_type = "image/webp"
            elif url_lower.endswith(".svg"):
                mime_type = "image/svg+xml"
            elif url_lower.endswith(".bmp"):
                mime_type = "image/bmp"
            elif url_lower.endswith(".ico"):
                mime_type = "image/x-icon"

            media_objects.append(
                {
                    "type": "photo",
                    "url": url,
                    "mime_type": mime_type,
                    "width": None,
                    "height": None,
                }
            )

    return media_objects
