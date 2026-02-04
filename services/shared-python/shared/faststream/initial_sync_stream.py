"""NATS JetStream configuration for feed initial sync events."""

from faststream.nats import JStream
from nats.js.api import RetentionPolicy, StorageType

INITIAL_SYNC_STREAM_NAME = "FEED_SYNC"
INITIAL_SYNC_SUBJECT = "feed.initial_sync"
INITIAL_SYNC_STREAM_SUBJECTS = [INITIAL_SYNC_SUBJECT]


def create_initial_sync_stream() -> JStream:
    """Create JStream configuration for FEED_SYNC stream.

    Uses WORK_QUEUE retention - messages are deleted after first ACK.
    """
    return JStream(
        name=INITIAL_SYNC_STREAM_NAME,
        subjects=INITIAL_SYNC_STREAM_SUBJECTS,
        retention=RetentionPolicy.WORK_QUEUE,
        storage=StorageType.FILE,
        max_age=7 * 24 * 60 * 60,  # 7 days
        max_bytes=256 * 1024 * 1024,  # 256MB
        num_replicas=1,
        declare=True,
    )
