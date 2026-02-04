"""Pydantic models for RuStore webhook payloads.

NOTE: These models are based on RuStore API documentation and may require
updates after receiving real webhook payloads from RuStore sandbox/production.
"""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class RuStoreWebhookPayload(BaseModel):
    """Decrypted RuStore webhook payload.

    This model represents the structure after AES-256-GCM decryption.
    Fields are based on RuStore API v4 subscription response format.

    NOTE: Exact structure may differ from real webhooks and require updates.
    """

    # Subscription identification
    purchase_token: str = Field(
        alias="purchaseToken",
        description="Subscription token (purchaseId) - unique identifier",
    )
    order_id: str = Field(alias="orderId", description="RuStore order ID")
    product_id: str | None = Field(
        default=None,
        alias="productId",
        description="Product/subscription ID from RuStore Console",
    )
    package_name: str | None = Field(
        default=None, alias="packageName", description="Application package name"
    )

    # Event type and status
    event_type: str | None = Field(
        default=None,
        alias="eventType",
        description="Event type: purchase, renewal, cancellation, etc.",
    )
    payment_state: int = Field(
        alias="paymentState",
        description="Payment state: 0 (pending), 1 (received), 2 (free trial)",
    )
    previous_payment_state: int | None = Field(
        default=None,
        alias="previousPaymentState",
        description="Previous payment state (for status changes)",
    )

    # Subscription details
    start_time_millis: int = Field(
        alias="startTimeMillis", description="Subscription start timestamp (ms)"
    )
    expiry_time_millis: int = Field(
        alias="expiryTimeMillis", description="Subscription expiry timestamp (ms)"
    )
    auto_renewing: bool = Field(
        alias="autoRenewing", description="Whether subscription auto-renews"
    )

    # Pricing information
    price_amount_micros: int = Field(
        alias="priceAmountMicros",
        description="Price in micros (1/1,000,000 of currency)",
    )
    price_currency_code: str = Field(
        alias="priceCurrencyCode", description="Currency code (e.g., RUB)"
    )

    # Acknowledgement and cancellation
    acknowledgement_state: int = Field(
        alias="acknowledgementState",
        description="Acknowledgement state: 0 (not acknowledged), 1 (acknowledged)",
    )
    cancel_reason: int | None = Field(
        default=None,
        alias="cancelReason",
        description="Cancellation reason code (if cancelled)",
    )

    # Webhook metadata
    notification_id: str | None = Field(
        default=None,
        alias="notificationId",
        description="Unique notification ID from RuStore",
    )
    timestamp: int | None = Field(
        default=None, alias="timestamp", description="Webhook send timestamp (ms)"
    )

    model_config = ConfigDict(populate_by_name=True)

    def get_expiry_datetime(self) -> datetime:
        """Convert expiry timestamp to datetime."""
        from datetime import timezone

        return datetime.fromtimestamp(self.expiry_time_millis / 1000, tz=timezone.utc)

    def get_start_datetime(self) -> datetime:
        """Convert start timestamp to datetime."""
        from datetime import timezone

        return datetime.fromtimestamp(self.start_time_millis / 1000, tz=timezone.utc)


class RuStoreWebhookRequest(BaseModel):
    """Incoming webhook request from RuStore.

    This is the raw encrypted request before decryption.
    """

    payload: str = Field(
        description="Base64-encoded AES-256-GCM encrypted payload from RuStore"
    )


class RuStoreWebhookResponse(BaseModel):
    """Response to RuStore webhook."""

    success: bool = Field(description="Whether webhook was processed successfully")
    message: str | None = Field(
        default=None, description="Optional message (for errors or logging)"
    )


class RuStoreWebhookProcessingResult(BaseModel):
    """Internal result of webhook processing."""

    success: bool
    subscription_id: str | None = None
    event_type: str | None = None
    payment_state: int | None = None
    error_message: str | None = None
    raw_payload: dict[str, Any] | None = None
