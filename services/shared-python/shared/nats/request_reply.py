"""Request-Reply pattern utilities for NATS."""

import asyncio
import json
from collections.abc import Callable
from typing import Any, TypeVar

from loguru import logger
from nats.aio.client import Client as NATSClient
from nats.aio.msg import Msg
from nats.errors import NoRespondersError
from pydantic import BaseModel

from shared.context import get_request_id, set_request_id
from shared.nats.logging import (
    log_nats_consume_end,
    log_nats_consume_start,
    log_rpc_request,
    log_rpc_response,
    log_rpc_timeout,
    nats_timing,
)
from shared.sentry_utils import capture_exception

T = TypeVar("T", bound=BaseModel)


class RequestReplyClient:
    """Client for making request-reply calls over NATS."""

    def __init__(self, nc: NATSClient) -> None:
        """Initialize request-reply client.

        Args:
            nc: NATS client instance
        """
        self._nc = nc

    async def request(
        self,
        subject: str,
        payload: bytes | str | BaseModel,
        timeout: float = 10.0,
        headers: dict[str, str] | None = None,
    ) -> Msg:
        """Send a request and wait for a response.

        Args:
            subject: Subject to send request to
            payload: Request payload
            timeout: Response timeout in seconds
            headers: Optional request headers

        Returns:
            Response message

        Raises:
            asyncio.TimeoutError: If no response within timeout
            Exception: If request fails
        """
        if isinstance(payload, BaseModel):
            data = payload.model_dump_json().encode()
        elif isinstance(payload, str):
            data = payload.encode()
        else:
            data = payload

        request_headers = dict(headers) if headers else {}
        request_id = get_request_id()
        if request_id:
            request_headers["X-Request-ID"] = request_id

        ctx = log_rpc_request(subject, data, timeout)

        try:
            with nats_timing() as timing:
                response = await self._nc.request(
                    subject,
                    data,
                    timeout=timeout,
                    headers=request_headers if request_headers else None,
                )

            log_rpc_response(
                ctx,
                response.data,
                timing["duration_ms"],
                success=True,
            )
            return response
        except asyncio.TimeoutError as e:
            log_rpc_timeout(subject, timeout, timeout * 1000)
            capture_exception(
                e,
                tags={"service": "nats", "operation": "request"},
                extras={"subject": subject, "timeout": timeout},
            )
            raise
        except NoRespondersError:
            log_rpc_response(
                ctx,
                None,
                0,
                success=False,
                error="No responders - target service may be down",
            )
            raise
        except Exception as e:
            logger.error(f"Request to {subject} failed: {e}")
            capture_exception(
                e,
                tags={"service": "nats", "operation": "request"},
                extras={"subject": subject},
            )
            raise

    async def request_json(
        self,
        subject: str,
        request: BaseModel,
        response_type: type[T],
        timeout: float = 10.0,
    ) -> T:
        """Send a typed request and parse the response.

        Args:
            subject: Subject to send request to
            request: Request Pydantic model
            response_type: Expected response Pydantic model type
            timeout: Response timeout in seconds

        Returns:
            Parsed response model

        Raises:
            asyncio.TimeoutError: If no response within timeout
            ValidationError: If response parsing fails
        """
        response = await self.request(subject, request, timeout)
        return response_type.model_validate_json(response.data)


class RequestReplyHandler:
    """Handler for responding to request-reply calls over NATS."""

    def __init__(self, nc: NATSClient) -> None:
        """Initialize request-reply handler.

        Args:
            nc: NATS client instance
        """
        self._nc = nc
        self._subscriptions: list[Any] = []

    async def subscribe(
        self,
        subject: str,
        handler: Callable[[Msg], Any],
        queue: str | None = None,
    ) -> Any:
        """Subscribe to a subject with a handler function.

        Args:
            subject: Subject to subscribe to
            handler: Async function to handle incoming messages
            queue: Optional queue group for load balancing

        Returns:
            Subscription object
        """
        sub = await self._nc.subscribe(subject, queue=queue, cb=handler)
        self._subscriptions.append(sub)
        logger.info(
            f"Subscribed to {subject}" + (f" (queue: {queue})" if queue else "")
        )
        return sub

    async def subscribe_handler(
        self,
        subject: str,
        request_type: type[BaseModel],
        handler: Callable[[BaseModel], Any],
        queue: str | None = None,
    ) -> Any:
        """Subscribe with automatic request parsing and response sending.

        Args:
            subject: Subject to subscribe to
            request_type: Expected request Pydantic model type
            handler: Async function that takes parsed request and returns response
            queue: Optional queue group for load balancing

        Returns:
            Subscription object
        """

        async def wrapper(msg: Msg) -> None:
            request_id = None

            msg_request_id = None
            if msg.headers:
                msg_request_id = msg.headers.get("X-Request-ID")
            set_request_id(msg_request_id)

            with logger.contextualize(request_id=msg_request_id):
                ctx = log_nats_consume_start(
                    subject=subject,
                    payload=msg.data,
                )

                try:
                    with nats_timing() as timing:
                        request = request_type.model_validate_json(msg.data)
                        if hasattr(request, "request_id"):
                            request_id = str(request.request_id)

                        response = await handler(request)

                        if response is not None:
                            if isinstance(response, BaseModel):
                                response_data = response.model_dump_json().encode()
                            elif isinstance(response, str):
                                response_data = response.encode()
                            else:
                                response_data = response

                            await msg.respond(response_data)

                    log_nats_consume_end(
                        ctx, timing["duration_ms"], success=True, response=response
                    )
                except Exception as e:
                    log_nats_consume_end(ctx, 0, success=False, error=str(e))
                    capture_exception(
                        e,
                        tags={"service": "nats", "operation": "handler"},
                        extras={"subject": subject, "request_id": request_id},
                    )
                    error_response: dict[str, Any] = {"error": str(e), "success": False}
                    if request_id:
                        error_response["request_id"] = request_id
                    await msg.respond(json.dumps(error_response).encode())

        return await self.subscribe(subject, wrapper, queue)

    async def unsubscribe_all(self) -> None:
        """Unsubscribe from all subjects."""
        for sub in self._subscriptions:
            try:
                await sub.unsubscribe()
            except Exception as e:
                logger.error(f"Error unsubscribing: {e}")
        self._subscriptions.clear()
        logger.info("Unsubscribed from all subjects")


def create_request_client(nc: NATSClient) -> RequestReplyClient:
    """Create a request-reply client.

    Args:
        nc: NATS client

    Returns:
        RequestReplyClient instance
    """
    return RequestReplyClient(nc)


def create_request_handler(nc: NATSClient) -> RequestReplyHandler:
    """Create a request-reply handler.

    Args:
        nc: NATS client

    Returns:
        RequestReplyHandler instance
    """
    return RequestReplyHandler(nc)
