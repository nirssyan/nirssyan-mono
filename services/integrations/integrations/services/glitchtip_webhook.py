"""Service for processing GlitchTip webhooks.

GlitchTip sends Slack-compatible webhooks with attachments containing error info.
This service processes them and sends notifications to Telegram.
"""

import httpx
from loguru import logger

from shared.models.glitchtip_webhook import (
    GlitchTipWebhookPayload,
    GlitchTipWebhookProcessingResult,
)

from ..config import settings


class GlitchTipWebhookService:
    """Service for processing GlitchTip webhooks."""

    def _extract_issue_id(self, title_link: str | None) -> str | None:
        """Extract issue ID from GlitchTip URL."""
        if not title_link:
            return None
        parts = title_link.rstrip("/").split("/")
        if parts and parts[-1].isdigit():
            return parts[-1]
        return None

    def format_telegram_message(self, payload: GlitchTipWebhookPayload) -> str:
        """Format webhook payload for Telegram message."""
        if not payload.attachments:
            return "🔴 <b>GlitchTip Alert</b>\n\n⚠️ Empty alert (no error details)"

        attachment = payload.attachments[0]
        issue_id = self._extract_issue_id(attachment.title_link)
        header = (
            f"🔴 <b>GlitchTip Alert #{issue_id}</b>"
            if issue_id
            else "🔴 <b>GlitchTip Alert</b>"
        )
        lines = [header, ""]

        if attachment.title:
            lines.append(f"⚠️ <b>Error:</b> {self._escape_html(attachment.title)}")

        if attachment.text:
            lines.append(f"📍 <code>{self._escape_html(attachment.text)}</code>")

        lines.append("")

        for field in attachment.fields:
            emoji = self._get_field_emoji(field.title)
            lines.append(f"{emoji} {field.title}: {self._escape_html(field.value)}")

        if attachment.title_link:
            lines.append("")
            lines.append(f'🔗 <a href="{attachment.title_link}">View in GlitchTip</a>')

        return "\n".join(lines)

    def _get_field_emoji(self, field_title: str) -> str:
        """Get emoji for field title."""
        emojis = {
            "Project": "🏷️",
            "Environment": "🌍",
            "Release": "📦",
            "Level": "📊",
            "Count": "🔢",
        }
        return emojis.get(field_title, "•")

    def _escape_html(self, text: str) -> str:
        """Escape HTML special characters."""
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    async def send_telegram_notification(self, message: str) -> bool:
        """Send notification to Telegram.

        Uses the same Telegram config as Sentry webhook.
        """
        bot_token = settings.sentry_webhook_telegram_bot_token
        chat_id = settings.sentry_webhook_telegram_chat_id
        thread_id = settings.sentry_webhook_telegram_thread_id

        if not bot_token or not chat_id:
            logger.warning("Telegram credentials not configured for GlitchTip webhook")
            return False

        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }

        if thread_id:
            payload["message_thread_id"] = thread_id

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, json=payload)

                if response.status_code == 200:
                    logger.info("GlitchTip webhook notification sent to Telegram")
                    return True

                logger.error(
                    f"Failed to send Telegram notification: "
                    f"{response.status_code} - {response.text[:200]}"
                )
                return False

        except httpx.TimeoutException:
            logger.error("Timeout sending GlitchTip notification to Telegram")
            return False
        except httpx.RequestError as e:
            logger.error(f"Network error sending GlitchTip notification: {e}")
            return False

    async def process_webhook(
        self,
        payload: GlitchTipWebhookPayload,
    ) -> GlitchTipWebhookProcessingResult:
        """Process an incoming GlitchTip webhook."""
        try:
            error_title = None
            if payload.attachments:
                error_title = payload.attachments[0].title

            logger.info(f"GlitchTip webhook received: error={error_title}")

            message = self.format_telegram_message(payload)
            telegram_sent = await self.send_telegram_notification(message)

            return GlitchTipWebhookProcessingResult(
                success=True,
                error_title=error_title,
                telegram_sent=telegram_sent,
            )

        except Exception as e:
            logger.error(f"Error processing GlitchTip webhook: {e}", exc_info=True)
            return GlitchTipWebhookProcessingResult(
                success=False,
                error_message=str(e),
            )
