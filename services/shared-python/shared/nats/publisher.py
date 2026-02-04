"""JetStream publisher for publishing events to NATS."""

from nats.js import JetStreamContext
from nats.js.api import PubAck
from pydantic import BaseModel

from shared.context import get_request_id
from shared.nats.logging import log_nats_publish, nats_timing


class JetStreamPublisher:
    """Publisher for JetStream messages."""

    def __init__(self, js: JetStreamContext) -> None:
        """Initialize publisher with JetStream context.

        Args:
            js: JetStream context from NATSClientManager
        """
        self._js = js

    async def publish(
        self,
        subject: str,
        payload: bytes | str | BaseModel,
        headers: dict[str, str] | None = None,
        event_type: str | None = None,
    ) -> PubAck:
        """Publish a message to a JetStream subject.

        Args:
            subject: Subject to publish to (e.g., 'posts.new.telegram')
            payload: Message payload (bytes, string, or Pydantic model)
            headers: Optional message headers
            event_type: Optional event type for structured logging

        Returns:
            PubAck with stream and sequence info

        Raises:
            Exception: If publish fails
        """
        if isinstance(payload, BaseModel):
            data = payload.model_dump_json().encode()
        elif isinstance(payload, str):
            data = payload.encode()
        else:
            data = payload

        publish_headers = dict(headers) if headers else {}
        request_id = get_request_id()
        if request_id:
            publish_headers["X-Request-ID"] = request_id

        with nats_timing() as timing:
            ack = await self._js.publish(
                subject, data, headers=publish_headers if publish_headers else None
            )

        log_nats_publish(
            subject=subject,
            payload=data,
            stream=ack.stream,
            duration_ms=timing["duration_ms"],
            event_type=event_type,
        )
        return ack

    async def publish_event(
        self,
        event: BaseModel,
        subject: str | None = None,
    ) -> PubAck:
        """Publish a Pydantic event model to JetStream.

        The subject is determined from the event's event_type field if not provided.

        Args:
            event: Pydantic event model with event_type field
            subject: Optional explicit subject (overrides event_type)

        Returns:
            PubAck with stream and sequence info
        """
        event_type = getattr(event, "event_type", None)
        if subject is None:
            if event_type is None:
                raise ValueError(
                    "Event must have event_type field or subject must be provided"
                )
            subject = event_type.replace(".", "_")

        return await self.publish(subject, event, event_type=event_type)


def create_publisher(js: JetStreamContext) -> JetStreamPublisher:
    """Factory function to create a JetStreamPublisher.

    Args:
        js: JetStream context

    Returns:
        Configured JetStreamPublisher
    """
    return JetStreamPublisher(js)
