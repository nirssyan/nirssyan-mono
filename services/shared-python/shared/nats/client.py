"""NATS client singleton for inter-service communication."""

import asyncio
from typing import Any

import nats
from loguru import logger
from nats.aio.client import Client as NATSClient
from nats.js import JetStreamContext


class NATSClientManager:
    """Singleton manager for NATS client connections."""

    _instance: "NATSClientManager | None" = None
    _lock: asyncio.Lock | None = None

    def __new__(cls) -> "NATSClientManager":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialized:  # type: ignore[has-type]
            return
        self._nc: NATSClient | None = None
        self._js: JetStreamContext | None = None
        self._connected = False
        self._initialized = True

    @classmethod
    def get_lock(cls) -> asyncio.Lock:
        if cls._lock is None:
            cls._lock = asyncio.Lock()
        return cls._lock

    async def connect(
        self,
        servers: str | list[str],
        connect_timeout: float = 10.0,
        reconnect_time_wait: float = 2.0,
        max_reconnect_attempts: int = 60,
        name: str | None = None,
    ) -> None:
        """Connect to NATS server(s).

        Args:
            servers: NATS server URL or list of URLs
            connect_timeout: Connection timeout in seconds
            reconnect_time_wait: Time to wait between reconnects
            max_reconnect_attempts: Maximum reconnect attempts
            name: Client name for identification
        """
        async with self.get_lock():
            if self._connected and self._nc is not None:
                logger.debug("NATS already connected")
                return

            if isinstance(servers, str):
                servers = [servers]

            async def error_cb(e: Exception) -> None:
                logger.error(f"NATS error: {e}")

            async def disconnected_cb() -> None:
                logger.warning("NATS disconnected")

            async def reconnected_cb() -> None:
                logger.info("NATS reconnected")

            async def closed_cb() -> None:
                logger.info("NATS connection closed")

            try:
                self._nc = await nats.connect(
                    servers=servers,
                    connect_timeout=connect_timeout,
                    reconnect_time_wait=reconnect_time_wait,
                    max_reconnect_attempts=max_reconnect_attempts,
                    error_cb=error_cb,
                    disconnected_cb=disconnected_cb,
                    reconnected_cb=reconnected_cb,
                    closed_cb=closed_cb,
                    name=name,
                )
                self._js = self._nc.jetstream()
                self._connected = True
                logger.info(f"Connected to NATS: {servers}")
            except Exception as e:
                logger.error(f"Failed to connect to NATS: {e}")
                raise

    async def disconnect(self) -> None:
        """Disconnect from NATS server."""
        async with self.get_lock():
            if self._nc is not None:
                try:
                    await self._nc.drain()
                    await self._nc.close()
                except Exception as e:
                    logger.error(f"Error closing NATS connection: {e}")
                finally:
                    self._nc = None
                    self._js = None
                    self._connected = False
                    logger.info("NATS disconnected")

    @property
    def nc(self) -> NATSClient:
        """Get the NATS client instance."""
        if self._nc is None:
            raise RuntimeError("NATS client not connected")
        return self._nc

    @property
    def js(self) -> JetStreamContext:
        """Get the JetStream context."""
        if self._js is None:
            raise RuntimeError("NATS JetStream not initialized")
        return self._js

    @property
    def is_connected(self) -> bool:
        """Check if connected to NATS."""
        return self._connected and self._nc is not None and self._nc.is_connected

    async def ensure_stream(
        self,
        name: str,
        subjects: list[str],
        retention: str = "workqueue",
        max_age: int = 7 * 24 * 60 * 60,  # 7 days in seconds
        max_bytes: int = 1024 * 1024 * 1024,  # 1GB
        storage: str = "file",
        replicas: int = 1,
    ) -> Any:
        """Ensure a JetStream stream exists with the given configuration.

        Args:
            name: Stream name
            subjects: List of subjects the stream captures
            retention: Retention policy (workqueue, limits, interest)
            max_age: Maximum age of messages in seconds
            max_bytes: Maximum stream size in bytes
            storage: Storage type (file, memory)
            replicas: Number of replicas

        Returns:
            StreamInfo object
        """
        from nats.js.api import RetentionPolicy, StorageType, StreamConfig

        retention_map = {
            "workqueue": RetentionPolicy.WORK_QUEUE,
            "limits": RetentionPolicy.LIMITS,
            "interest": RetentionPolicy.INTEREST,
        }

        storage_map = {
            "file": StorageType.FILE,
            "memory": StorageType.MEMORY,
        }

        config = StreamConfig(
            name=name,
            subjects=subjects,
            retention=retention_map.get(retention, RetentionPolicy.WORK_QUEUE),
            max_age=max_age,
            max_bytes=max_bytes,
            storage=storage_map.get(storage, StorageType.FILE),
            num_replicas=replicas,
        )

        try:
            stream_info = await self.js.stream_info(name)
            logger.debug(f"Stream '{name}' already exists")
            return stream_info
        except Exception:
            stream_info = await self.js.add_stream(config)
            logger.info(f"Created stream '{name}' with subjects {subjects}")
            return stream_info


# Global singleton instance
nats_client = NATSClientManager()
