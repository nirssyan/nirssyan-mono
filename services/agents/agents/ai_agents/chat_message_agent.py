"""Chat message AI agent for collecting feed parameters."""

from __future__ import annotations

import asyncio
import json
import re
from typing import TYPE_CHECKING, Any

from loguru import logger

from .base_agent import BaseJSONAgent
from .prompts import CHAT_MESSAGE_SYSTEM_PROMPT
from .schemas import (
    ChatMessageAIResponse,
    SourceValidationOutput,
)

if TYPE_CHECKING:
    from ..services.source_validation import SourceValidationService


class ChatMessageAgent(BaseJSONAgent[ChatMessageAIResponse]):
    """Agent for processing chat messages and collecting feed parameters using LangChain."""

    def __init__(
        self,
        source_validation_service: SourceValidationService | None = None,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        """Initialize the chat message agent.

        Args:
            source_validation_service: Service for validating feed sources.
                If provided, agent will automatically validate URLs in user messages.
            api_key: API key. If None, will use config settings.
            base_url: Base URL. If None, will use config settings.
            model: Model to use for generation. If None, defaults from config.
        """
        # Store validation service for use in process_message
        self.source_validation_service = source_validation_service

        super().__init__(
            response_model=ChatMessageAIResponse,
            system_prompt=CHAT_MESSAGE_SYSTEM_PROMPT,
            human_prompt_template="{input_data}",
            api_key=api_key,
            base_url=base_url,
            model=model,
            temperature=0.7,  # Pass for metadata linking
        )

    async def _extract_and_validate_urls(
        self, user_message: str
    ) -> list[SourceValidationOutput]:
        """Extract and validate potential source URLs from user message.

        Args:
            user_message: The user's message text

        Returns:
            List of validation results for detected URLs
        """
        if not self.source_validation_service:
            return []

        # Patterns for detecting potential sources

        patterns = [
            r"https?://t\.me/addlist/[\w-]+",  # Telegram folder invite
            r"@[\w]+",  # Telegram @username
            r"t\.me/[\w]+",  # t.me/channel
            r"https?://t\.me/[\w]+",  # https://t.me/channel
            r"https?://[^\s]+",  # Any HTTP URL
            # Domain without scheme (e.g., kod.ru, example.com)
            # Uses negative lookbehind to avoid matching:
            # - @domain (Telegram)
            # - /domain (path)
            # - part of URL like "od.ru" in "https://kod.ru"
            # - https://domain or http://domain (already matched above)
            # - www.domain (already matched via https?://)
            # Uses non-capturing groups (?:...) to avoid tuple results
            # Uses fixed-width lookbehinds for Python compatibility
            # Matches domain.tld (min 2 parts) and subdomain.domain.tld (3+ parts)
            r"(?<![/@a-z0-9])(?<!https://)(?<!http://)(?<!www\.)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?![/@])",
        ]

        detected_urls = set()
        for pattern in patterns:
            matches = re.findall(pattern, user_message, re.IGNORECASE)
            detected_urls.update(matches)
        # Validate all detected URLs in parallel with lightweight mode (fast validation for chat)

        async def validate_single_url(url: str) -> SourceValidationOutput:
            """Validate a single URL and return result.

            Args:
                url: URL to validate

            Returns:
                Validation result
            """
            # Type assertion: source_validation_service is guaranteed to be non-None
            # because we checked at line 117-118
            assert self.source_validation_service is not None

            # Normalize URL: add https:// if no scheme present
            # Skip for Telegram handles (@channel) and t.me shortcuts
            url_to_validate = url
            if not url.startswith(("http://", "https://", "@", "t.me/")):
                url_to_validate = f"https://{url}"
                logger.debug(f"Normalized URL '{url}' → '{url_to_validate}'")

            try:
                # Use lightweight=True for fast validation without parsing articles
                # This speeds up validation from 3-5 sec to 0.5-1 sec per URL
                result = await self.source_validation_service.validate_source(
                    url_to_validate, lightweight=True
                )
                logger.info(
                    f"Validated URL '{url_to_validate}' (lightweight): valid={result.valid}, type={result.source_type}"
                )
                return SourceValidationOutput(
                    url=url,  # Original URL from user message
                    valid=result.valid,
                    source_type=result.source_type,
                    message=result.message,
                    detected_feed_url=result.detected_feed_url,
                )
            except Exception as e:
                logger.error(f"Failed to validate URL '{url_to_validate}': {e}")
                return SourceValidationOutput(
                    url=url,
                    valid=False,
                    source_type=None,
                    message=f"Validation error: {str(e)}",
                    detected_feed_url=None,
                )

        # Validate all URLs in parallel
        if detected_urls:
            validation_results = await asyncio.gather(
                *[validate_single_url(url) for url in detected_urls]
            )
        else:
            validation_results = []

        return list(validation_results)

    async def process_message(
        self,
        user_message: str,
        current_state: dict[str, Any] | None = None,
        chat_history: list[dict[str, Any]] | None = None,
        user_id: str | None = None,
    ) -> tuple[ChatMessageAIResponse, list[SourceValidationOutput]]:
        """Process user message and return AI response with collected parameters.

        Args:
            user_message: The user's message.
            current_state: Current state of pre_prompt (prompt, sources, type).
            chat_history: Recent chat messages for context.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            Tuple of (ChatMessageAIResponse, validation_results list).

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Extract and validate URLs from user message if service is available
        validation_results = await self._extract_and_validate_urls(user_message)

        # Prepare input data for the AI agent
        input_data = {
            "user_message": user_message,
            "current_state": current_state
            or {
                "prompt": None,
                "sources": None,
                "source_types": None,
                "type": None,
            },
            "chat_history": chat_history or [],
            "validation_results": [vr.model_dump() for vr in validation_results],
        }

        # Convert to JSON string as expected by the n8n workflow
        input_json = json.dumps(input_data, ensure_ascii=False, indent=2)

        ai_response = await self._invoke_chain_async(
            {"input_data": input_json}, "process_message", user_id=user_id
        )
        return ai_response, validation_results

    def process_message_sync(
        self,
        user_message: str,
        current_state: dict[str, Any] | None = None,
        chat_history: list[dict[str, Any]] | None = None,
        user_id: str | None = None,
    ) -> ChatMessageAIResponse:
        """Synchronous version of process_message.

        Args:
            user_message: The user's message.
            current_state: Current state of pre_prompt (prompt, sources, type).
            chat_history: Recent chat messages for context.
            user_id: Optional user ID (unused, kept for API compatibility).

        Returns:
            ChatMessageAIResponse with response, current_feed_info, and suggestions.

        Raises:
            ValueError: If validation fails or generation errors occur.
        """
        # Prepare input data for the AI agent
        input_data = {
            "user_message": user_message,
            "current_state": current_state
            or {
                "prompt": None,
                "sources": None,
                "type": None,
            },
            "chat_history": chat_history or [],
        }

        # Convert to JSON string as expected by the n8n workflow
        input_json = json.dumps(input_data, ensure_ascii=False, indent=2)

        return self._invoke_chain_sync(
            {"input_data": input_json}, "process_message_sync", user_id=user_id
        )
