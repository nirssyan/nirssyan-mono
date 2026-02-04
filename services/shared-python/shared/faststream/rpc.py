"""FastStream RPC (Request-Reply) pattern support for NATS."""

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar
from uuid import uuid4

from faststream.nats import NatsBroker, NatsMessage
from loguru import logger
from pydantic import BaseModel

from shared.context import get_request_id
from shared.faststream.broker import get_broker
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
RequestHandler = Callable[[BaseModel], Awaitable[BaseModel]]


class RPCClient:
    """RPC client for NATS request-reply pattern.

    Uses FastStream's broker.request() method for synchronous
    request-reply communication.
    """

    def __init__(self, broker: NatsBroker | None = None):
        """Initialize RPC client.

        Args:
            broker: NatsBroker instance. If None, uses singleton.
        """
        self._broker = broker

    @property
    def broker(self) -> NatsBroker:
        """Get broker instance, falling back to singleton."""
        if self._broker is None:
            self._broker = get_broker()
        return self._broker

    async def request(
        self,
        subject: str,
        message: bytes | str | dict[str, Any] | BaseModel,
        timeout: float = 10.0,
        headers: dict[str, str] | None = None,
    ) -> NatsMessage:
        """Send a request and wait for a reply.

        Args:
            subject: NATS subject to send request to.
            message: Request payload.
            timeout: Request timeout in seconds.
            headers: Optional message headers.

        Returns:
            NatsMessage containing the reply.

        Raises:
            asyncio.TimeoutError: If request times out.
        """
        if isinstance(message, BaseModel):
            payload = message.model_dump_json()
        elif isinstance(message, dict):
            import json

            payload = json.dumps(message)
        else:
            payload = message

        if isinstance(payload, str):
            payload_bytes = payload.encode()
        else:
            payload_bytes = payload

        correlation_id = str(uuid4())
        request_headers = headers or {}
        request_headers["correlation_id"] = correlation_id

        request_id = get_request_id()
        if request_id:
            request_headers["X-Request-ID"] = request_id

        ctx = log_rpc_request(subject, payload_bytes, timeout)

        try:
            with nats_timing() as timing:
                response: NatsMessage = await asyncio.wait_for(
                    self.broker.request(
                        message=payload,
                        subject=subject,
                        headers=request_headers,
                    ),
                    timeout=timeout,
                )

            response_data = response.raw_message.data if response.raw_message else b""
            log_rpc_response(ctx, response_data, timing["duration_ms"], success=True)
            return response
        except asyncio.TimeoutError as e:
            log_rpc_timeout(subject, timeout, timeout * 1000)
            capture_exception(
                e,
                tags={"service": "faststream", "operation": "rpc_request"},
                extras={
                    "subject": subject,
                    "timeout": timeout,
                },
            )
            raise

    async def request_json(
        self,
        subject: str,
        request: BaseModel,
        response_type: type[T],
        timeout: float = 10.0,
        headers: dict[str, str] | None = None,
    ) -> T:
        """Send a typed request and parse the typed response.

        Args:
            subject: NATS subject to send request to.
            request: Pydantic request model.
            response_type: Expected Pydantic response type.
            timeout: Request timeout in seconds.
            headers: Optional message headers.

        Returns:
            Parsed response as the specified Pydantic type.

        Raises:
            asyncio.TimeoutError: If request times out.
            ValidationError: If response doesn't match expected type.
        """
        response = await self.request(
            subject=subject,
            message=request,
            timeout=timeout,
            headers=headers,
        )

        response_data = await response.decode()

        if isinstance(response_data, dict):
            return response_type.model_validate(response_data)
        elif isinstance(response_data, str):
            import json

            return response_type.model_validate(json.loads(response_data))
        elif isinstance(response_data, bytes):
            import json

            return response_type.model_validate(json.loads(response_data.decode()))
        else:
            return response_type.model_validate(response_data)


class RPCHandler:
    """RPC handler for registering request-reply handlers.

    Provides a high-level API for registering typed request handlers
    that automatically deserialize requests and serialize responses.
    """

    def __init__(self, broker: NatsBroker | None = None):
        """Initialize RPC handler.

        Args:
            broker: NatsBroker instance. If None, uses singleton.
        """
        self._broker = broker
        self._handlers: dict[str, Any] = {}

    @property
    def broker(self) -> NatsBroker:
        """Get broker instance, falling back to singleton."""
        if self._broker is None:
            self._broker = get_broker()
        return self._broker

    def register_handler(
        self,
        subject: str,
        request_type: type[BaseModel],
        handler: Callable[[BaseModel], Awaitable[BaseModel]],
        queue: str | None = None,
    ) -> Callable[[NatsMessage], Awaitable[BaseModel]]:
        """Register a typed request handler.

        This creates a subscriber that:
        1. Deserializes incoming messages to request_type
        2. Calls the handler with the typed request
        3. Returns the handler's response for automatic reply

        Args:
            subject: NATS subject to listen on.
            request_type: Pydantic type for incoming requests.
            handler: Async function that takes request and returns response.
            queue: Optional queue group for load balancing.

        Returns:
            The wrapped handler function (for testing).
        """

        async def wrapped_handler(msg: NatsMessage) -> BaseModel:
            """Deserialize, handle, and return response."""
            payload = msg.raw_message.data if msg.raw_message else b""
            ctx = log_nats_consume_start(subject=subject, payload=payload)

            try:
                data = await msg.decode()
                if isinstance(data, dict):
                    request = request_type.model_validate(data)
                elif isinstance(data, str):
                    import json

                    request = request_type.model_validate(json.loads(data))
                elif isinstance(data, bytes):
                    import json

                    request = request_type.model_validate(json.loads(data.decode()))
                else:
                    request = request_type.model_validate(data)

                with nats_timing() as timing:
                    response = await handler(request)

                log_nats_consume_end(
                    ctx, timing["duration_ms"], success=True, response=response
                )
                return response

            except Exception as e:
                log_nats_consume_end(ctx, 0, success=False, error=str(e))
                logger.error(f"RPC handler error on {subject}: {e}")
                capture_exception(
                    e,
                    tags={"service": "faststream", "operation": "rpc_handler"},
                    extras={"subject": subject},
                )
                raise

        subscriber_kwargs: dict[str, Any] = {"subject": subject}
        if queue:
            subscriber_kwargs["queue"] = queue

        self.broker.subscriber(**subscriber_kwargs)(wrapped_handler)
        self._handlers[subject] = wrapped_handler

        logger.info(
            f"Registered RPC handler: {subject}"
            + (f" (queue: {queue})" if queue else "")
        )
        return wrapped_handler


_rpc_client: RPCClient | None = None
_rpc_handler: RPCHandler | None = None


def get_rpc_client() -> RPCClient:
    """Get singleton RPC client instance."""
    global _rpc_client
    if _rpc_client is None:
        _rpc_client = RPCClient()
    return _rpc_client


def get_rpc_handler() -> RPCHandler:
    """Get singleton RPC handler instance."""
    global _rpc_handler
    if _rpc_handler is None:
        _rpc_handler = RPCHandler()
    return _rpc_handler


def create_rpc_client(broker: NatsBroker | None = None) -> RPCClient:
    """Create a new RPC client instance."""
    return RPCClient(broker)


def create_rpc_handler(broker: NatsBroker | None = None) -> RPCHandler:
    """Create a new RPC handler instance."""
    return RPCHandler(broker)
