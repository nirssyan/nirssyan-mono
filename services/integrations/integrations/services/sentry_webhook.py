"""Sentry webhook service for Telegram notifications."""

import httpx
from loguru import logger

from shared.models.sentry_webhook import (
    SentryWebhookPayload,
    SentryWebhookProcessingResult,
)

from ..config import settings


class SentryWebhookService:
    """Service for processing Sentry webhooks."""

    ACTION_EMOJIS: dict[str, str] = {
        "created": "🔴",
        "resolved": "✅",
        "assigned": "👤",
        "archived": "📦",
        "unresolved": "🔄",
    }

    ACTION_TITLES: dict[str, str] = {
        "created": "New Issue Created",
        "resolved": "Issue Resolved",
        "assigned": "Issue Assigned",
        "archived": "Issue Archived",
        "unresolved": "Issue Reopened",
    }

    LEVEL_EMOJIS: dict[str, str] = {
        "fatal": "💀",
        "error": "🔴",
        "warning": "🟡",
        "info": "🔵",
        "debug": "⚪",
    }

    def format_telegram_message(self, payload: SentryWebhookPayload) -> str:
        """Format webhook payload for Telegram message."""
        action = payload.action
        issue = payload.data.issue

        action_emoji = self.ACTION_EMOJIS.get(action, "📌")
        action_title = self.ACTION_TITLES.get(action, action.title())
        level_emoji = self.LEVEL_EMOJIS.get(issue.level, "🔴")

        emoji = level_emoji if action == "created" else action_emoji

        lines = [
            f"{emoji} <b>Sentry: {action_title}</b>",
            "",
            f"<b>{issue.shortId}</b>: {self._escape_html(issue.title)}",
        ]

        if issue.metadata and issue.metadata.type:
            error_info = issue.metadata.type
            if issue.metadata.value:
                error_info += f" - {self._truncate(issue.metadata.value, 100)}"
            lines.append(f"⚠️ <code>{self._escape_html(error_info)}</code>")

        if issue.culprit:
            lines.append(f"📍 <code>{self._escape_html(issue.culprit)}</code>")

        stats_parts = []
        if issue.count:
            stats_parts.append(f"Events: {issue.count}")
        if issue.userCount:
            stats_parts.append(f"Users: {issue.userCount}")
        if stats_parts:
            lines.append(f"📊 {' | '.join(stats_parts)}")

        link = issue.permalink or issue.web_url
        if link:
            lines.append(f'🔗 <a href="{link}">View in Sentry</a>')

        footer_parts = [f"Project: {issue.project.name}"]
        if issue.level:
            footer_parts.append(f"Level: {issue.level}")
        if issue.priority:
            footer_parts.append(f"Priority: {issue.priority}")
        lines.append("")
        lines.append(f"<i>{' | '.join(footer_parts)}</i>")

        if payload.actor and action in ("assigned", "resolved"):
            actor_name = payload.actor.name or payload.actor.id or "Unknown"
            lines.append(f"<i>By: {self._escape_html(actor_name)}</i>")

        return "\n".join(lines)

    def _escape_html(self, text: str) -> str:
        """Escape HTML special characters."""
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    def _truncate(self, text: str, max_length: int) -> str:
        """Truncate text with ellipsis."""
        if len(text) <= max_length:
            return text
        return text[: max_length - 3] + "..."

    async def send_telegram_notification(self, message: str) -> bool:
        """Send notification to Telegram."""
        bot_token = settings.sentry_webhook_telegram_bot_token
        chat_id = settings.sentry_webhook_telegram_chat_id
        thread_id = settings.sentry_webhook_telegram_thread_id

        if not bot_token or not chat_id:
            logger.warning("Telegram credentials not configured for Sentry webhook")
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
                    logger.info("Sentry webhook notification sent to Telegram")
                    return True

                logger.error(
                    f"Failed to send Telegram notification: "
                    f"{response.status_code} - {response.text[:200]}"
                )
                return False

        except httpx.TimeoutException:
            logger.error("Timeout sending Sentry notification to Telegram")
            return False
        except httpx.RequestError as e:
            logger.error(f"Network error sending Sentry notification: {e}")
            return False

    async def process_webhook(
        self,
        payload: SentryWebhookPayload,
    ) -> SentryWebhookProcessingResult:
        """Process an incoming Sentry webhook."""
        try:
            action = payload.action
            issue_id = payload.data.issue.shortId
            logger.info(f"Sentry webhook received: action={action}, issue={issue_id}")

            message = self.format_telegram_message(payload)
            telegram_sent = await self.send_telegram_notification(message)

            return SentryWebhookProcessingResult(
                success=True,
                action=action,
                issue_id=issue_id,
                telegram_sent=telegram_sent,
            )

        except Exception as e:
            logger.error(f"Error processing Sentry webhook: {e}", exc_info=True)
            return SentryWebhookProcessingResult(
                success=False,
                error_message=str(e),
            )
