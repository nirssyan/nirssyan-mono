"""Sentry webhook controller."""

import json
from typing import Any

from litestar import Controller, Request, post
from litestar.exceptions import HTTPException
from litestar.status_codes import (
    HTTP_400_BAD_REQUEST,
    HTTP_500_INTERNAL_SERVER_ERROR,
)
from loguru import logger
from pydantic import ValidationError

from shared.models.sentry_webhook import (
    SentryWebhookPayload,
    SentryWebhookResponse,
)

from ..config import settings
from ..services.sentry_webhook import SentryWebhookService


class SentryWebhookController(Controller):
    """Controller for Sentry webhook endpoints."""

    path = "/webhooks/sentry"
    tags = ["Sentry"]

    @post("/notifications", status_code=200)
    async def handle_notification(
        self,
        request: Request,
        data: dict[str, Any],
        sentry_webhook_service: SentryWebhookService,
    ) -> SentryWebhookResponse:
        """Handle Sentry webhook notifications.

        This endpoint receives JSON notifications from Sentry
        and forwards formatted notifications to Telegram.
        No signature verification is performed for simplified setup.

        Args:
            request: HTTP request (for accessing headers)
            data: Parsed webhook payload (raw dict for debugging)
            sentry_webhook_service: Webhook processing service

        Returns:
            Success response

        Raises:
            HTTPException: 400 for processing errors, 500 for config errors
        """
        try:
            resource = request.headers.get("Sentry-Hook-Resource", "unknown")
            timestamp = request.headers.get("Sentry-Hook-Timestamp", "")
            logger.info(
                f"Received Sentry webhook: resource={resource}, timestamp={timestamp}"
            )

            # DEBUG: Log raw payload
            logger.info(
                f"RAW SENTRY PAYLOAD: {json.dumps(data, indent=2, default=str)}"
            )

            # Validate payload manually
            try:
                payload = SentryWebhookPayload.model_validate(data)
            except ValidationError as e:
                logger.error(f"Validation error: {e}")
                logger.error(f"Payload keys: {list(data.keys())}")
                if "data" in data:
                    logger.error(f"data keys: {list(data['data'].keys())}")
                raise HTTPException(
                    status_code=HTTP_400_BAD_REQUEST,
                    detail=f"Invalid payload: {e}",
                ) from e

            if not settings.sentry_webhook_telegram_bot_token:
                logger.error("Sentry webhook Telegram bot token not configured")
                raise HTTPException(
                    status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Webhook processing not configured",
                )

            result = await sentry_webhook_service.process_webhook(payload=payload)

            if not result.success:
                logger.error(
                    f"Sentry webhook processing failed: {result.error_message}"
                )
                raise HTTPException(
                    status_code=HTTP_400_BAD_REQUEST,
                    detail=result.error_message or "Webhook processing failed",
                )

            logger.info(
                f"Sentry webhook processed: action={result.action}, "
                f"issue={result.issue_id}, telegram_sent={result.telegram_sent}"
            )

            return SentryWebhookResponse(
                success=True,
                message=f"Notification processed: {result.action} - {result.issue_id}",
            )

        except HTTPException:
            raise

        except Exception as e:
            logger.error(f"Error processing Sentry webhook: {e}", exc_info=True)
            raise HTTPException(
                status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Internal server error: {e!s}",
            ) from e
