"""NATS JetStream configuration for DIGEST scheduled messages."""

from faststream.nats import JStream
from nats.js.api import RetentionPolicy, StorageType

DIGEST_STREAM_NAME = "DIGESTS"
DIGEST_PENDING_SUBJECT = "digest.pending"
DIGEST_EXECUTE_SUBJECT = "digest.execute"
DIGEST_STREAM_SUBJECTS = [DIGEST_PENDING_SUBJECT, DIGEST_EXECUTE_SUBJECT]


def create_digest_stream() -> JStream:
    """Create JStream configuration for DIGESTS stream.

    Uses LIMITS retention (not WORK_QUEUE) because scheduled messages
    need to persist until their scheduled time, not until first ACK.

    Enables allow_msg_schedules for JetStream Schedule API (FastStream 0.6.4+).
    """
    return JStream(
        name=DIGEST_STREAM_NAME,
        subjects=DIGEST_STREAM_SUBJECTS,
        retention=RetentionPolicy.LIMITS,
        storage=StorageType.FILE,
        max_age=30 * 24 * 60 * 60,  # 30 days max
        max_bytes=256 * 1024 * 1024,  # 256MB
        num_replicas=1,
        allow_msg_schedules=True,
        declare=True,
    )
