"""Service for scheduling digest executions via NATS JetStream."""

import asyncio
from datetime import datetime, timedelta, timezone
from uuid import UUID

from faststream.nats import NatsBroker, Schedule
from loguru import logger

from shared.events.digest_scheduled import DigestScheduledEvent
from shared.faststream.digest_stream import (
    DIGEST_EXECUTE_SUBJECT,
    DIGEST_PENDING_SUBJECT,
    DIGEST_STREAM_NAME,
)

MAX_RETRY_ATTEMPTS = 3
INITIAL_RETRY_DELAY_SECONDS = 1.0


class DigestScheduler:
    """Schedules digest executions using NATS JetStream scheduled messages."""

    def __init__(self, broker: NatsBroker) -> None:
        self.broker = broker

    async def schedule_next_digest(
        self,
        prompt_id: UUID,
        interval_hours: int,
    ) -> None:
        """Schedule next digest execution with retry logic.

        Uses FastStream Schedule API to publish a message that will be delivered
        at the scheduled time. The message is published to DIGEST_PENDING_SUBJECT
        and scheduled to be delivered to DIGEST_EXECUTE_SUBJECT.

        Implements exponential backoff retry (1s -> 2s -> 4s) for transient NATS errors.

        Args:
            prompt_id: ID of the prompt to execute
            interval_hours: Hours until next execution

        Raises:
            Exception: If all retry attempts fail
        """
        scheduled_at = datetime.now(timezone.utc) + timedelta(hours=interval_hours)

        event = DigestScheduledEvent(
            prompt_id=prompt_id,
            scheduled_at=scheduled_at,
            interval_hours=interval_hours,
        )

        schedule = Schedule(
            time=scheduled_at,
            target=DIGEST_EXECUTE_SUBJECT,
        )

        last_error: Exception | None = None
        for attempt in range(MAX_RETRY_ATTEMPTS):
            try:
                await self.broker.publish(
                    message=event.model_dump(mode="json"),
                    subject=DIGEST_PENDING_SUBJECT,
                    stream=DIGEST_STREAM_NAME,
                    schedule=schedule,
                )
                logger.info(
                    f"Scheduled digest for prompt={prompt_id} at {scheduled_at} "
                    f"(interval={interval_hours}h)"
                )
                return
            except Exception as e:
                last_error = e
                if attempt < MAX_RETRY_ATTEMPTS - 1:
                    delay = INITIAL_RETRY_DELAY_SECONDS * (2**attempt)
                    logger.warning(
                        f"Failed to schedule digest for prompt={prompt_id} "
                        f"(attempt {attempt + 1}/{MAX_RETRY_ATTEMPTS}): {e}. "
                        f"Retrying in {delay}s..."
                    )
                    await asyncio.sleep(delay)

        logger.error(
            f"Failed to schedule digest for prompt={prompt_id} after "
            f"{MAX_RETRY_ATTEMPTS} attempts: {last_error}"
        )
        raise last_error  # type: ignore[misc]
