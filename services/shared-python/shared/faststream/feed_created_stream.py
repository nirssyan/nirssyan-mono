"""NATS JetStream configuration for feed created events."""

from faststream.nats import JStream
from nats.js.api import RetentionPolicy, StorageType

FEED_CREATED_STREAM_NAME = "FEED_CREATED"
FEED_CREATED_SUBJECT = "feed.created"
FEED_CREATED_STREAM_SUBJECTS = [FEED_CREATED_SUBJECT]
FEED_CREATED_CONSUMER_NAME = "feed-created-processor"


def create_feed_created_stream() -> JStream:
    """Create JStream configuration for FEED_CREATED stream.

    Uses WORK_QUEUE retention - messages are deleted after first ACK.
    """
    return JStream(
        name=FEED_CREATED_STREAM_NAME,
        subjects=FEED_CREATED_STREAM_SUBJECTS,
        retention=RetentionPolicy.WORK_QUEUE,
        storage=StorageType.FILE,
        max_age=7 * 24 * 60 * 60,  # 7 days
        max_bytes=512 * 1024 * 1024,  # 512MB (larger for complex events)
        num_replicas=1,
        declare=True,
    )
