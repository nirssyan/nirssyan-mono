"""FastStream NATS JetStream utilities.

This module provides FastStream-based NATS JetStream integration:
- NatsBroker singleton for connection management
- JetStream stream/consumer configuration
- Publisher and subscriber patterns
- Request-Reply (RPC) pattern support
"""

from shared.faststream.broker import (
    BrokerConfig,
    StreamConfig,
    close_broker,
    create_broker,
    get_broker,
    get_jstream,
)
from shared.faststream.digest_stream import (
    DIGEST_EXECUTE_SUBJECT,
    DIGEST_PENDING_SUBJECT,
    DIGEST_STREAM_NAME,
    DIGEST_STREAM_SUBJECTS,
    create_digest_stream,
)
from shared.faststream.initial_sync_stream import (
    INITIAL_SYNC_STREAM_NAME,
    INITIAL_SYNC_STREAM_SUBJECTS,
    INITIAL_SYNC_SUBJECT,
    create_initial_sync_stream,
)
from shared.faststream.publisher import (
    FastStreamPublisher,
    create_publisher,
    get_publisher,
)
from shared.faststream.rpc import (
    RPCClient,
    RPCHandler,
    create_rpc_client,
    create_rpc_handler,
    get_rpc_client,
    get_rpc_handler,
)
from shared.faststream.subscriber import (
    ConsumerConfig,
    JetStreamConsumer,
    create_consumer,
    create_pull_subscriber,
    create_typed_handler,
)

__all__ = [
    # Broker
    "create_broker",
    "get_broker",
    "get_jstream",
    "close_broker",
    "BrokerConfig",
    "StreamConfig",
    # Publisher
    "FastStreamPublisher",
    "create_publisher",
    "get_publisher",
    # RPC
    "RPCClient",
    "RPCHandler",
    "create_rpc_client",
    "create_rpc_handler",
    "get_rpc_client",
    "get_rpc_handler",
    # Subscriber
    "ConsumerConfig",
    "JetStreamConsumer",
    "create_consumer",
    "create_pull_subscriber",
    "create_typed_handler",
    # Digest Stream
    "DIGEST_STREAM_NAME",
    "DIGEST_PENDING_SUBJECT",
    "DIGEST_EXECUTE_SUBJECT",
    "DIGEST_STREAM_SUBJECTS",
    "create_digest_stream",
    # Initial Sync Stream
    "INITIAL_SYNC_STREAM_NAME",
    "INITIAL_SYNC_SUBJECT",
    "INITIAL_SYNC_STREAM_SUBJECTS",
    "create_initial_sync_stream",
]
