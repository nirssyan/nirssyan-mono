"""NATS JetStream client utilities."""

from shared.nats.client import NATSClientManager, nats_client
from shared.nats.logging import (
    NATSLogContext,
    log_nats_ack,
    log_nats_batch_summary,
    log_nats_consume_end,
    log_nats_consume_start,
    log_nats_nack,
    log_nats_publish,
    log_rpc_request,
    log_rpc_response,
    log_rpc_timeout,
    nats_timing,
)
from shared.nats.publisher import JetStreamPublisher, create_publisher
from shared.nats.request_reply import (
    RequestReplyClient,
    RequestReplyHandler,
    create_request_client,
    create_request_handler,
)

# Alias for backward compatibility and cleaner imports
NATSClient = NATSClientManager

__all__ = [
    "NATSClientManager",
    "NATSClient",
    "nats_client",
    "JetStreamPublisher",
    "create_publisher",
    "RequestReplyClient",
    "RequestReplyHandler",
    "create_request_client",
    "create_request_handler",
    # Logging utilities
    "NATSLogContext",
    "nats_timing",
    "log_nats_publish",
    "log_nats_consume_start",
    "log_nats_consume_end",
    "log_nats_ack",
    "log_nats_nack",
    "log_nats_batch_summary",
    "log_rpc_request",
    "log_rpc_response",
    "log_rpc_timeout",
]
