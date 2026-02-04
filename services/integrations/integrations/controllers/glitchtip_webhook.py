"""Controller for GlitchTip webhook endpoints.

GlitchTip sends Slack-compatible webhooks when alerts are triggered.
This controller receives them and forwards to Telegram.
"""

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

from shared.models.glitchtip_webhook import (
    GlitchTipWebhookPayload,
    GlitchTipWebhookResponse,
)

from ..config import settings
from ..services.glitchtip_webhook import GlitchTipWebhookService


class GlitchTipWebhookController(Controller):
    """Controller for GlitchTip webhook endpoints."""

    path = "/webhooks/glitchtip"
    tags = ["GlitchTip"]

    @post("/notifications", status_code=200)
    async def handle_notification(
        self,
        request: Request,
        data: dict[str, Any],
        glitchtip_webhook_service: GlitchTipWebhookService,
    ) -> GlitchTipWebhookResponse:
        """Handle GlitchTip webhook notifications.

        This endpoint receives Slack-compatible JSON notifications from GlitchTip
        and forwards formatted notifications to Telegram.
        Uses the same Telegram credentials as Sentry webhook.

        Args:
            request: HTTP request (for accessing headers)
            data: Parsed webhook payload (raw dict for debugging)
            glitchtip_webhook_service: Webhook processing service

        Returns:
            Success response

        Raises:
            HTTPException: 400 for processing errors, 500 for config errors
        """
        try:
            logger.info("Received GlitchTip webhook")
            logger.debug(
                f"GlitchTip payload: {json.dumps(data, indent=2, default=str)}"
            )

            try:
                payload = GlitchTipWebhookPayload.model_validate(data)
            except ValidationError as e:
                logger.error(f"Validation error: {e}")
                logger.error(f"Payload keys: {list(data.keys())}")
                raise HTTPException(
                    status_code=HTTP_400_BAD_REQUEST,
                    detail=f"Invalid payload: {e}",
                ) from e

            if not settings.sentry_webhook_telegram_bot_token:
                logger.error("Telegram bot token not configured for GlitchTip webhook")
                raise HTTPException(
                    status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Webhook processing not configured",
                )

            result = await glitchtip_webhook_service.process_webhook(payload=payload)

            if not result.success:
                logger.error(
                    f"GlitchTip webhook processing failed: {result.error_message}"
                )
                raise HTTPException(
                    status_code=HTTP_400_BAD_REQUEST,
                    detail=result.error_message or "Webhook processing failed",
                )

            logger.info(
                f"GlitchTip webhook processed: error={result.error_title}, "
                f"telegram_sent={result.telegram_sent}"
            )

            return GlitchTipWebhookResponse(
                success=True,
                message=f"Notification processed: {result.error_title or 'alert'}",
            )

        except HTTPException:
            raise

        except Exception as e:
            logger.error(f"Error processing GlitchTip webhook: {e}", exc_info=True)
            raise HTTPException(
                status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Internal server error: {e!s}",
            ) from e
