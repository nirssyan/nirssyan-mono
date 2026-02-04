"""App Store Connect webhook service for signature verification and Telegram notifications."""

import hashlib
import hmac
from typing import Any

import httpx
from loguru import logger

from shared.models.appstore_webhook import (
    AppStoreWebhookProcessingResult,
)

from ..config import settings


class SignatureVerificationError(Exception):
    """Raised when webhook signature verification fails."""


class AppStoreWebhookService:
    """Service for processing App Store Connect webhooks."""

    EVENT_EMOJIS: dict[str, str] = {
        "appStoreVersionAppVersionStateUpdated": "🚀",
        "buildUploadStateUpdated": "📦",
        "buildBetaDetailExternalBuildStateUpdated": "🧪",
        "betaFeedbackScreenshotSubmissionCreated": "📸",
        "betaFeedbackCrashSubmissionCreated": "💥",
        "webhookPingCreated": "🏓",
    }

    EVENT_TITLES: dict[str, str] = {
        "appStoreVersionAppVersionStateUpdated": "App Version State Changed",
        "buildUploadStateUpdated": "Build Upload Status",
        "buildBetaDetailExternalBuildStateUpdated": "TestFlight Build Status",
        "betaFeedbackScreenshotSubmissionCreated": "TestFlight Screenshot Feedback",
        "betaFeedbackCrashSubmissionCreated": "TestFlight Crash Report",
        "webhookPingCreated": "Webhook Ping",
    }

    def verify_signature(self, payload: bytes, signature: str) -> bool:
        """Verify HMAC-SHA256 signature from App Store Connect.

        Args:
            payload: Raw request body bytes
            signature: Signature from X-Apple-SIGNATURE header

        Returns:
            True if signature is valid

        Raises:
            SignatureVerificationError: If signature verification fails
        """
        secret = settings.appstore_webhook_secret
        if not secret:
            raise SignatureVerificationError("Webhook secret not configured")

        expected_signature = hmac.new(
            secret.encode("utf-8"),
            payload,
            hashlib.sha256,
        ).hexdigest()

        # Apple sends signature with "hmacsha256=" prefix
        actual_signature = signature
        if signature.startswith("hmacsha256="):
            actual_signature = signature[11:]  # Remove "hmacsha256=" prefix

        if not hmac.compare_digest(expected_signature, actual_signature):
            logger.warning(
                f"Signature mismatch - Apple: {actual_signature[:20]}..., "
                f"Expected: {expected_signature[:20]}..."
            )
            raise SignatureVerificationError("Invalid signature")

        return True

    def format_telegram_message(self, payload: dict[str, Any]) -> str:
        """Format webhook payload for Telegram message.

        Args:
            payload: Raw webhook payload dict

        Returns:
            HTML-formatted message for Telegram
        """
        data = payload.get("data", {})
        event_type = data.get("type", "unknown")
        emoji = self.EVENT_EMOJIS.get(event_type, "📱")
        title = self.EVENT_TITLES.get(event_type, event_type)

        lines = [
            f"{emoji} <b>App Store: {title}</b>",
            "",
        ]

        attributes = data.get("attributes", {})
        if attributes:
            if "oldState" in attributes and "newState" in attributes:
                lines.append(f"📊 {attributes['oldState']} → {attributes['newState']}")

            for key, value in attributes.items():
                if key not in ("oldState", "newState"):
                    lines.append(f"• {key}: <code>{value}</code>")

        event_id = data.get("id", "unknown")
        lines.append("")
        lines.append(
            f"<i>Event ID: {event_id[:8] if len(event_id) > 8 else event_id}...</i>"
        )

        return "\n".join(lines)

    async def send_telegram_notification(self, message: str) -> bool:
        """Send notification to Telegram.

        Args:
            message: HTML-formatted message to send

        Returns:
            True if sent successfully, False otherwise
        """
        bot_token = settings.appstore_telegram_bot_token
        chat_id = settings.appstore_telegram_chat_id
        thread_id = settings.appstore_telegram_thread_id

        if not bot_token or not chat_id:
            logger.warning("Telegram credentials not configured for App Store webhook")
            return False

        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "HTML",
        }

        if thread_id:
            payload["message_thread_id"] = thread_id

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, json=payload)

                if response.status_code == 200:
                    logger.info("App Store webhook notification sent to Telegram")
                    return True

                logger.error(
                    f"Failed to send Telegram notification: "
                    f"{response.status_code} - {response.text[:200]}"
                )
                return False

        except httpx.TimeoutException:
            logger.error("Timeout sending App Store notification to Telegram")
            return False
        except httpx.RequestError as e:
            logger.error(f"Network error sending App Store notification: {e}")
            return False

    async def process_webhook(
        self,
        payload: dict[str, Any],
    ) -> AppStoreWebhookProcessingResult:
        """Process an incoming App Store Connect webhook.

        Args:
            payload: Raw webhook payload dict

        Returns:
            Processing result with details
        """
        try:
            data = payload.get("data", {})
            event_type = data.get("type", "unknown")
            logger.info(f"App Store webhook received: type={event_type}")

            message = self.format_telegram_message(payload)
            telegram_sent = await self.send_telegram_notification(message)

            return AppStoreWebhookProcessingResult(
                success=True,
                event_type=event_type,
                telegram_sent=telegram_sent,
            )

        except Exception as e:
            logger.error(f"Error processing App Store webhook: {e}", exc_info=True)
            return AppStoreWebhookProcessingResult(
                success=False,
                error_message=str(e),
            )
