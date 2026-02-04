"""HTML to Markdown conversion utilities for RSS content."""

import re
from typing import cast

from markdownify import markdownify as md


class HTMLToMarkdownConverter:
    """Convert HTML content to clean Markdown format."""

    @staticmethod
    def convert(html: str) -> str:
        """Convert HTML to clean Markdown.

        Args:
            html: HTML content string

        Returns:
            Clean Markdown string
        """
        if not html or not html.strip():
            return ""

        # Convert HTML to Markdown using markdownify
        markdown = cast(
            str,
            md(
                html,
                strip=["script", "style"],  # Remove script and style tags
                heading_style="ATX",  # Use # headings instead of underline style
                bullets="-",  # Use - for bullet lists
                strong_em_symbol="**",  # Use ** for bold
                escape_asterisks=False,  # Don't escape asterisks in text
                escape_underscores=False,  # Don't escape underscores in text
            ),
        )

        # Clean up extra whitespace
        markdown = HTMLToMarkdownConverter._clean_whitespace(markdown)

        return markdown

    @staticmethod
    def _clean_whitespace(text: str) -> str:
        """Clean up excessive whitespace in markdown text.

        Args:
            text: Markdown text

        Returns:
            Cleaned text
        """
        # Remove trailing whitespace from each line
        text = "\n".join(line.rstrip() for line in text.split("\n"))

        # Replace 3+ newlines with 2 newlines
        text = re.sub(r"\n{3,}", "\n\n", text)

        # Remove leading/trailing whitespace
        text = text.strip()

        return text

    @staticmethod
    def create_preview(text: str, max_length: int = 300) -> str:
        """Create a preview/summary from text.

        Args:
            text: Full text content
            max_length: Maximum length of preview (default: 300)

        Returns:
            Preview text with ellipsis if truncated
        """
        if not text:
            return ""

        # Clean text first
        clean_text = text.strip()

        # If text is short enough, return as is
        if len(clean_text) <= max_length:
            return clean_text

        # Truncate at word boundary
        preview = clean_text[:max_length]

        # Find last space to avoid cutting words
        last_space = preview.rfind(" ")
        if last_space > max_length * 0.8:  # Only if we're not cutting too much
            preview = preview[:last_space]

        return preview + "..."
