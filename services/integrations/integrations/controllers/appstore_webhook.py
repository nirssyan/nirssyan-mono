"""App Store Connect webhook controller."""

from typing import Any

from litestar import Controller, Request, post
from litestar.exceptions import HTTPException
from litestar.status_codes import (
    HTTP_400_BAD_REQUEST,
    HTTP_401_UNAUTHORIZED,
    HTTP_500_INTERNAL_SERVER_ERROR,
)
from loguru import logger

from shared.models.appstore_webhook import (
    AppStoreWebhookResponse,
)

from ..config import settings
from ..services.appstore_webhook import (
    AppStoreWebhookService,
    SignatureVerificationError,
)


class AppStoreWebhookController(Controller):
    """Controller for App Store Connect webhook endpoints."""

    path = "/webhooks/appstore"
    tags = ["App Store"]

    @post("/notifications", status_code=200)
    async def handle_notification(
        self,
        request: Request,
        data: dict[str, Any],
        appstore_webhook_service: AppStoreWebhookService,
    ) -> AppStoreWebhookResponse:
        """Handle App Store Connect webhook notifications.

        This endpoint receives JSON notifications from App Store Connect,
        verifies the HMAC-SHA256 signature, and forwards formatted
        notifications to Telegram.

        Args:
            request: HTTP request (for accessing raw body and headers)
            data: Parsed webhook payload
            appstore_webhook_service: Webhook processing service

        Returns:
            Success response (required by Apple for delivery confirmation)

        Raises:
            HTTPException: 400 for processing errors, 401 for signature errors, 500 for config errors
        """
        try:
            raw_body = await request.body()
            logger.info(
                f"Received App Store Connect webhook, raw body: {raw_body.decode('utf-8')}"
            )

            if not settings.appstore_webhook_secret:
                logger.error("App Store webhook secret not configured")
                raise HTTPException(
                    status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Webhook processing not configured",
                )

            signature = request.headers.get("X-Apple-SIGNATURE", "")
            if not signature:
                logger.warning("Missing X-Apple-SIGNATURE header")
                raise HTTPException(
                    status_code=HTTP_401_UNAUTHORIZED,
                    detail="Missing signature header",
                )

            appstore_webhook_service.verify_signature(raw_body, signature)

            result = await appstore_webhook_service.process_webhook(payload=data)

            if not result.success:
                logger.error(
                    f"App Store webhook processing failed: {result.error_message}"
                )
                raise HTTPException(
                    status_code=HTTP_400_BAD_REQUEST,
                    detail=result.error_message or "Webhook processing failed",
                )

            logger.info(
                f"App Store webhook processed: type={result.event_type}, "
                f"telegram_sent={result.telegram_sent}"
            )

            return AppStoreWebhookResponse(
                success=True,
                message=f"Notification processed: {result.event_type}",
            )

        except SignatureVerificationError as e:
            logger.warning(f"Signature verification failed: {e}")
            raise HTTPException(
                status_code=HTTP_401_UNAUTHORIZED,
                detail=str(e),
            ) from e

        except HTTPException:
            raise

        except Exception as e:
            logger.error(f"Error processing App Store webhook: {e}", exc_info=True)
            raise HTTPException(
                status_code=HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Internal server error: {str(e)}",
            ) from e
