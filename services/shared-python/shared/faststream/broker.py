"""FastStream NATS broker configuration and singleton management."""

from dataclasses import dataclass, field
from typing import Any

from faststream.nats import JStream, NatsBroker
from faststream.nats.opentelemetry import NatsTelemetryMiddleware
from loguru import logger
from nats.js.api import RetentionPolicy, StorageType


@dataclass
class StreamConfig:
    """JetStream stream configuration."""

    name: str
    subjects: list[str]
    retention: RetentionPolicy = RetentionPolicy.WORK_QUEUE
    storage: StorageType = StorageType.FILE
    max_age: int = 7 * 24 * 60 * 60  # 7 days in seconds
    max_bytes: int = 1024 * 1024 * 1024  # 1GB
    replicas: int = 1
    allow_msg_schedules: bool = False

    def to_jstream(self) -> JStream:
        """Convert to FastStream JStream configuration."""
        return JStream(
            name=self.name,
            subjects=self.subjects,
            retention=self.retention,
            storage=self.storage,
            max_age=self.max_age,
            max_bytes=self.max_bytes,
            num_replicas=self.replicas,
            allow_msg_schedules=self.allow_msg_schedules,
            declare=True,
        )


@dataclass
class BrokerConfig:
    """NATS broker configuration."""

    servers: str | list[str] = "nats://localhost:4222"
    connect_timeout: float = 10.0
    reconnect_time_wait: float = 2.0
    max_reconnect_attempts: int = 60
    ping_interval: int = 120
    max_outstanding_pings: int = 2
    streams: list[StreamConfig] = field(default_factory=list)
    otel_enabled: bool = False

    @classmethod
    def from_settings(cls, settings: Any) -> "BrokerConfig":
        """Create BrokerConfig from application settings."""
        return cls(
            servers=settings.nats_url,
            streams=[
                StreamConfig(
                    name="RAW_POSTS",
                    subjects=[
                        "posts.new.telegram",
                        "posts.new.rss",
                        "posts.new.web",
                    ],
                    retention=RetentionPolicy.WORK_QUEUE,
                ),
            ],
            otel_enabled=getattr(settings, "otel_enabled", False),
        )


_broker: NatsBroker | None = None
_jstreams: dict[str, JStream] = {}


def create_broker(config: BrokerConfig | None = None) -> NatsBroker:
    """Create and configure NATS broker with JetStream support.

    Args:
        config: Broker configuration. If None, uses defaults.

    Returns:
        Configured NatsBroker instance.
    """
    global _broker, _jstreams

    if _broker is not None:
        logger.warning("Broker already exists, returning existing instance")
        return _broker

    if config is None:
        config = BrokerConfig()

    logger.info(f"Creating FastStream NatsBroker: {config.servers}")

    middlewares = (NatsTelemetryMiddleware(),) if config.otel_enabled else ()

    _broker = NatsBroker(
        servers=config.servers
        if isinstance(config.servers, list)
        else [config.servers],
        connect_timeout=config.connect_timeout,
        reconnect_time_wait=config.reconnect_time_wait,
        max_reconnect_attempts=config.max_reconnect_attempts,
        ping_interval=config.ping_interval,
        max_outstanding_pings=config.max_outstanding_pings,
        logger=None,
        middlewares=middlewares,
    )

    for stream_config in config.streams:
        jstream = stream_config.to_jstream()
        _jstreams[stream_config.name] = jstream
        logger.info(
            f"Configured JetStream: {stream_config.name} -> {stream_config.subjects}"
        )

    return _broker


def get_broker() -> NatsBroker:
    """Get the singleton broker instance.

    Returns:
        NatsBroker instance.

    Raises:
        RuntimeError: If broker has not been created yet.
    """
    if _broker is None:
        raise RuntimeError("Broker not initialized. Call create_broker() first.")
    return _broker


def get_jstream(name: str) -> JStream:
    """Get a configured JStream by name.

    Args:
        name: Stream name (e.g., "RAW_POSTS").

    Returns:
        JStream configuration.

    Raises:
        KeyError: If stream not found.
    """
    if name not in _jstreams:
        raise KeyError(
            f"JStream '{name}' not configured. Available: {list(_jstreams.keys())}"
        )
    return _jstreams[name]


async def close_broker() -> None:
    """Close the broker connection."""
    global _broker, _jstreams

    if _broker is not None:
        logger.info("Closing FastStream NatsBroker connection")
        await _broker.close()
        _broker = None
        _jstreams.clear()
