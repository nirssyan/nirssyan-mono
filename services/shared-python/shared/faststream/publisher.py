"""FastStream publisher for NATS JetStream."""

from typing import Any

from faststream.nats import NatsBroker
from pydantic import BaseModel

from shared.context import get_request_id
from shared.faststream.broker import get_broker, get_jstream
from shared.nats.logging import log_nats_publish, nats_timing


class FastStreamPublisher:
    """Publisher for NATS JetStream using FastStream.

    Provides methods to publish messages to JetStream subjects with
    automatic serialization of Pydantic models.
    """

    def __init__(self, broker: NatsBroker | None = None):
        """Initialize publisher.

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

    async def publish(
        self,
        message: bytes | str | dict[str, Any] | BaseModel,
        subject: str,
        stream: str | None = None,
        headers: dict[str, str] | None = None,
        timeout: float = 10.0,
    ) -> None:
        """Publish a message to NATS JetStream.

        Args:
            message: Message content (bytes, str, dict, or Pydantic model).
            subject: NATS subject to publish to.
            stream: JetStream stream name (for stream routing).
            headers: Optional message headers.
            timeout: Publish timeout in seconds.
        """
        if isinstance(message, BaseModel):
            payload = message.model_dump_json()
        elif isinstance(message, dict):
            import json

            payload = json.dumps(message)
        elif isinstance(message, str):
            payload = message
        else:
            payload = message

        publish_headers = dict(headers) if headers else {}
        request_id = get_request_id()
        if request_id:
            publish_headers["X-Request-ID"] = request_id

        kwargs: dict[str, Any] = {
            "message": payload,
            "subject": subject,
            "timeout": timeout,
        }

        if publish_headers:
            kwargs["headers"] = publish_headers

        if stream:
            jstream = get_jstream(stream)
            kwargs["stream"] = jstream.name

        payload_bytes = (
            payload.encode()
            if isinstance(payload, str)
            else payload
            if isinstance(payload, bytes)
            else payload.encode()
        )

        with nats_timing() as timing:
            await self.broker.publish(**kwargs)

        log_nats_publish(
            subject=subject,
            payload=payload_bytes,
            stream=stream,
            duration_ms=timing["duration_ms"],
        )

    async def publish_event(
        self,
        event: BaseModel,
        subject: str | None = None,
        stream: str = "RAW_POSTS",
        headers: dict[str, str] | None = None,
    ) -> None:
        """Publish a Pydantic event model to JetStream.

        This is a convenience method for publishing structured events.
        The subject can be inferred from the event's `event_type` attribute
        if not explicitly provided.

        Args:
            event: Pydantic event model to publish.
            subject: NATS subject. If None, uses event.event_type as subject pattern.
            stream: JetStream stream name.
            headers: Optional message headers.
        """
        if subject is None:
            if hasattr(event, "event_type"):
                subject = str(event.event_type).replace(".", "_")
            else:
                raise ValueError(
                    "Subject must be provided if event has no event_type attribute"
                )

        await self.publish(
            message=event,
            subject=subject,
            stream=stream,
            headers=headers,
        )


_publisher: FastStreamPublisher | None = None


def get_publisher() -> FastStreamPublisher:
    """Get singleton publisher instance."""
    global _publisher
    if _publisher is None:
        _publisher = FastStreamPublisher()
    return _publisher


def create_publisher(broker: NatsBroker | None = None) -> FastStreamPublisher:
    """Create a new publisher instance.

    Args:
        broker: Optional NatsBroker instance.

    Returns:
        FastStreamPublisher instance.
    """
    return FastStreamPublisher(broker)
