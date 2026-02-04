"""FastStream subscriber utilities for NATS JetStream."""

from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

from faststream import AckPolicy
from faststream.nats import NatsBroker, NatsMessage, PullSub
from loguru import logger
from pydantic import BaseModel

from shared.faststream.broker import get_broker, get_jstream

T = TypeVar("T", bound=BaseModel)
MessageHandler = Callable[[T], Awaitable[None]]


class ConsumerConfig:
    """Configuration for JetStream consumer."""

    def __init__(
        self,
        stream: str,
        subject: str,
        durable_name: str,
        batch_size: int = 10,
        ack_wait_seconds: int = 60,
        max_deliver: int = 3,
        ack_policy: AckPolicy = AckPolicy.REJECT_ON_ERROR,
        max_workers: int = 10,
        queue: str | None = None,
    ):
        """Initialize consumer configuration.

        Args:
            stream: JetStream stream name.
            subject: Subject filter pattern (e.g., "posts.new.*").
            durable_name: Durable consumer name for persistence.
            batch_size: Number of messages to fetch per batch.
            ack_wait_seconds: Time before unacked message is redelivered.
            max_deliver: Maximum delivery attempts before DLQ.
            ack_policy: Acknowledgment policy for message handling.
            max_workers: Number of concurrent message handlers (default: 10).
            queue: Optional queue group for load balancing.
        """
        self.stream = stream
        self.subject = subject
        self.durable_name = durable_name
        self.batch_size = batch_size
        self.ack_wait_seconds = ack_wait_seconds
        self.max_deliver = max_deliver
        self.ack_policy = ack_policy
        self.max_workers = max_workers
        self.queue = queue


def create_pull_subscriber(
    broker: NatsBroker,
    config: ConsumerConfig,
    handler: Callable[[NatsMessage], Awaitable[Any]],
) -> Callable[..., Awaitable[Any]]:
    """Create a pull subscription consumer with FastStream.

    Args:
        broker: NatsBroker instance.
        config: Consumer configuration.
        handler: Async message handler function.

    Returns:
        Decorated handler function.
    """
    jstream = get_jstream(config.stream)

    pull_sub = PullSub(
        batch_size=config.batch_size,
    )

    subscriber_kwargs: dict[str, Any] = {
        "subject": config.subject,
        "stream": jstream,
        "pull_sub": pull_sub,
        "ack_policy": config.ack_policy,
        "max_workers": config.max_workers,
        "durable": config.durable_name,
    }

    if config.queue:
        subscriber_kwargs["queue"] = config.queue

    decorated_handler = broker.subscriber(**subscriber_kwargs)(handler)

    logger.info(
        f"Created pull subscriber: {config.subject} "
        f"(stream: {config.stream}, durable: {config.durable_name}, "
        f"batch: {config.batch_size}, workers: {config.max_workers})"
    )

    return decorated_handler


def create_typed_handler(
    message_type: type[T],
    handler: Callable[[T], Awaitable[None]],
) -> Callable[[NatsMessage], Awaitable[None]]:
    """Create a typed message handler that deserializes to Pydantic model.

    Args:
        message_type: Pydantic model type for messages.
        handler: Async handler that receives typed messages.

    Returns:
        Wrapped handler that deserializes and processes messages.
    """

    async def typed_handler(msg: NatsMessage) -> None:
        """Deserialize message and call typed handler."""
        try:
            data = await msg.decode()

            if isinstance(data, dict):
                typed_msg = message_type.model_validate(data)
            elif isinstance(data, str):
                import json

                typed_msg = message_type.model_validate(json.loads(data))
            elif isinstance(data, bytes):
                import json

                typed_msg = message_type.model_validate(json.loads(data.decode()))
            else:
                typed_msg = message_type.model_validate(data)

            await handler(typed_msg)

        except Exception as e:
            logger.error(f"Error processing message: {e}")
            raise

    return typed_handler


class JetStreamConsumer:
    """High-level JetStream consumer using FastStream pull subscription.

    This class provides a convenient interface for creating consumers
    that process messages from JetStream with automatic deserialization.
    """

    def __init__(
        self,
        broker: NatsBroker | None = None,
        config: ConsumerConfig | None = None,
    ):
        """Initialize consumer.

        Args:
            broker: NatsBroker instance. If None, uses singleton.
            config: Consumer configuration.
        """
        self._broker = broker
        self._config = config
        self._running = False

    @property
    def broker(self) -> NatsBroker:
        """Get broker instance, falling back to singleton."""
        if self._broker is None:
            self._broker = get_broker()
        return self._broker

    def register_handler(
        self,
        message_type: type[T],
        handler: Callable[[T], Awaitable[None]],
        config: ConsumerConfig | None = None,
    ) -> Callable[..., Awaitable[Any]]:
        """Register a typed message handler.

        Args:
            message_type: Pydantic model type for incoming messages.
            handler: Async handler function.
            config: Optional consumer config override.

        Returns:
            Decorated handler.
        """
        consumer_config = config or self._config
        if consumer_config is None:
            raise ValueError("Consumer config required")

        typed_handler = create_typed_handler(message_type, handler)
        return create_pull_subscriber(self.broker, consumer_config, typed_handler)

    async def start(self) -> None:
        """Start the consumer (connect broker if needed)."""
        if not self.broker._connection:
            await self.broker.start()
        self._running = True
        logger.info("JetStream consumer started")

    async def stop(self) -> None:
        """Stop the consumer."""
        self._running = False
        logger.info("JetStream consumer stopped")

    @property
    def is_running(self) -> bool:
        """Check if consumer is running."""
        return self._running


def create_consumer(
    stream: str = "RAW_POSTS",
    subject: str = "posts.new.*",
    durable_name: str = "processor-consumer",
    batch_size: int = 10,
    max_workers: int = 10,
    broker: NatsBroker | None = None,
) -> JetStreamConsumer:
    """Factory function to create a JetStream consumer.

    Args:
        stream: JetStream stream name.
        subject: Subject filter pattern.
        durable_name: Durable consumer name.
        batch_size: Messages per batch.
        max_workers: Concurrent handlers.
        broker: Optional broker instance.

    Returns:
        Configured JetStreamConsumer.
    """
    config = ConsumerConfig(
        stream=stream,
        subject=subject,
        durable_name=durable_name,
        batch_size=batch_size,
        max_workers=max_workers,
    )

    return JetStreamConsumer(broker=broker, config=config)
