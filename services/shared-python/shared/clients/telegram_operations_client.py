"""Telegram operations client using NATS RPC via NatsBroker.

This client is designed for services that use FastStream NatsBroker
(like makefeed-processor) to communicate with makefeed-telegram.
"""

from datetime import datetime
from typing import Any
from uuid import uuid4

from faststream.nats import NatsBroker
from loguru import logger
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from shared.context import get_request_id
from shared.events.telegram_operations import (
    NATS_SUBJECTS,
    ChannelResolveRequest,
    ChannelResolveResponse,
    GetMessagesRequest,
    GetMessagesResponse,
    TelegramMessageData,
    WarmMediaCacheRequest,
    WarmMediaCacheResponse,
)


class TelegramOperationsClientError(Exception):
    """Error from Telegram operations client."""

    pass


class TelegramOperationsClient:
    """Client for Telegram operations via NATS RPC.

    Uses NatsBroker for request-reply pattern, compatible with
    FastStream-based services.

    Example:
        broker = create_processor_broker()
        client = TelegramOperationsClient(broker, timeout=30.0)
        info = await client.resolve_channel_info("@durov")
    """

    def __init__(
        self,
        broker: NatsBroker,
        timeout: float = 30.0,
    ) -> None:
        """Initialize the Telegram operations client.

        Args:
            broker: FastStream NatsBroker instance
            timeout: Request timeout in seconds
        """
        self._broker = broker
        self._timeout = timeout

    @retry(
        retry=retry_if_exception_type(TimeoutError),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        reraise=True,
        before_sleep=lambda retry_state: logger.warning(
            f"NATS timeout, retrying ({retry_state.attempt_number}/3)..."
        ),
    )
    async def resolve_channel_info(self, url: str) -> dict[str, Any] | None:
        """Resolve Telegram channel info by URL.

        Args:
            url: Telegram channel URL (@channel or t.me/... link)

        Returns:
            Dictionary with chat_id, username, title or None if not found

        Raises:
            TelegramOperationsClientError: If request fails
        """
        request = ChannelResolveRequest(
            request_id=uuid4(),
            url=url,
        )

        logger.debug(f"Resolving Telegram channel via NATS: {url}")

        headers: dict[str, str] = {}
        request_id = get_request_id()
        if request_id:
            headers["X-Request-ID"] = request_id

        try:
            response_msg = await self._broker.request(
                message=request.model_dump(mode="json"),
                subject=NATS_SUBJECTS["channel_resolve"],
                timeout=self._timeout,
                headers=headers if headers else None,
            )

            data = await response_msg.decode()
            response = ChannelResolveResponse.model_validate(data)

            if not response.success:
                logger.warning(f"Channel resolution failed: {response.error}")
                return None

            logger.info(
                f"Channel resolved: {response.username} (chat_id={response.chat_id})"
            )

            return {
                "chat_id": response.chat_id,
                "username": response.username,
                "title": response.title,
            }

        except TimeoutError as e:
            logger.error(f"Telegram RPC timeout resolving {url}: {e}")
            raise TelegramOperationsClientError(
                f"Telegram service timeout: {url}"
            ) from e
        except Exception as e:
            if isinstance(e, TelegramOperationsClientError):
                raise
            logger.error(f"Telegram RPC error resolving {url}: {e}")
            raise TelegramOperationsClientError(f"Telegram service error: {e}") from e

    @retry(
        retry=retry_if_exception_type(TimeoutError),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        reraise=True,
        before_sleep=lambda retry_state: logger.warning(
            f"NATS timeout, retrying ({retry_state.attempt_number}/3)..."
        ),
    )
    async def get_channel_messages(
        self,
        channel_username: str,
        limit: int = 100,
        min_posts_after_grouping: int | None = None,
        since_date: datetime | None = None,
    ) -> list[TelegramMessageData]:
        """Get messages from a Telegram channel.

        Args:
            channel_username: Channel username without @
            limit: Maximum number of messages to fetch
            min_posts_after_grouping: If provided, keep fetching batches until
                this many posts after media grouping. Respects FloodWait.
            since_date: If provided, get all messages newer than this date

        Returns:
            List of TelegramMessageData objects

        Raises:
            TelegramOperationsClientError: If request fails
        """
        request = GetMessagesRequest(
            request_id=uuid4(),
            channel_username=channel_username,
            limit=limit,
            min_posts_after_grouping=min_posts_after_grouping,
            since_date=since_date,
        )

        logger.debug(f"Getting messages from {channel_username} via NATS")

        headers: dict[str, str] = {}
        request_id = get_request_id()
        if request_id:
            headers["X-Request-ID"] = request_id

        try:
            response_msg = await self._broker.request(
                message=request.model_dump(mode="json"),
                subject=NATS_SUBJECTS["get_messages"],
                timeout=self._timeout,
                headers=headers if headers else None,
            )

            data = await response_msg.decode()
            response = GetMessagesResponse.model_validate(data)

            if not response.success:
                logger.warning(f"Get messages failed: {response.error}")
                raise TelegramOperationsClientError(
                    f"Failed to get messages: {response.error}"
                )

            logger.info(
                f"Got {len(response.messages)} messages from {channel_username}"
            )
            return response.messages

        except TimeoutError as e:
            logger.error(
                f"Telegram RPC timeout getting messages from {channel_username}: {e}"
            )
            raise TelegramOperationsClientError(
                f"Telegram service timeout: {channel_username}"
            ) from e
        except Exception as e:
            if isinstance(e, TelegramOperationsClientError):
                raise
            logger.error(
                f"Telegram RPC error getting messages from {channel_username}: {e}"
            )
            raise TelegramOperationsClientError(f"Telegram service error: {e}") from e

    async def warm_media_cache(
        self,
        media_objects: list[dict[str, Any]],
        timeout_seconds: float = 30.0,
    ) -> WarmMediaCacheResponse:
        """Warm media cache for a list of media objects.

        Pre-caches media to S3 before sending WebSocket notifications.
        This ensures media URLs are ready when frontend fetches post details.

        Args:
            media_objects: List of media objects with url, type, preview_url
            timeout_seconds: Maximum time to wait for caching (default 30s)

        Returns:
            WarmMediaCacheResponse with caching statistics

        Raises:
            TelegramOperationsClientError: If request fails completely
        """
        if not media_objects:
            return WarmMediaCacheResponse(
                request_id=uuid4(),
                success=True,
                cached=0,
                skipped=0,
                errors=0,
                timed_out=False,
            )

        request = WarmMediaCacheRequest(
            media_objects=media_objects,
            timeout_seconds=timeout_seconds,
        )

        logger.debug(f"Warming media cache for {len(media_objects)} objects via NATS")

        headers: dict[str, str] = {}
        request_id = get_request_id()
        if request_id:
            headers["X-Request-ID"] = request_id

        try:
            response_msg = await self._broker.request(
                message=request.model_dump(mode="json"),
                subject=NATS_SUBJECTS["warm_media_cache"],
                timeout=timeout_seconds + 10.0,  # Extra buffer for RPC overhead
                headers=headers if headers else None,
            )

            data = await response_msg.decode()
            response = WarmMediaCacheResponse.model_validate(data)

            if not response.success:
                logger.warning(f"Media cache warming failed: {response.error}")

            logger.info(
                f"Media cache warming completed: cached={response.cached}, "
                f"skipped={response.skipped}, errors={response.errors}, "
                f"timed_out={response.timed_out}"
            )
            return response

        except TimeoutError as e:
            logger.warning(f"Telegram RPC timeout warming media cache: {e}")
            return WarmMediaCacheResponse(
                request_id=request.request_id,
                success=True,  # Graceful degradation
                cached=0,
                skipped=0,
                errors=0,
                timed_out=True,
            )
        except Exception as e:
            if isinstance(e, TelegramOperationsClientError):
                raise
            logger.warning(f"Telegram RPC error warming media cache: {e}")
            return WarmMediaCacheResponse(
                request_id=request.request_id,
                success=True,  # Graceful degradation
                cached=0,
                skipped=0,
                errors=0,
                timed_out=False,
                error=str(e),
            )
