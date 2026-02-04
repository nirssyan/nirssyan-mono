"""Pydantic models for subscription operations."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from shared.enums import (
    SubscriptionPlanType,
    SubscriptionPlatform,
    SubscriptionStatus,
)


class SubscriptionPlanResponse(BaseModel):
    """Subscription plan information."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    plan_type: SubscriptionPlanType = Field(examples=["PRO", "FREE"])
    feeds_limit: int = Field(examples=[10, 3, 50])
    sources_per_feed_limit: int = Field(examples=[20, 5, 100])
    price_amount_micros: int | None = Field(
        default=None, examples=[4990000, 9990000, None]
    )
    is_active: bool = Field(examples=[True, False])
    created_at: datetime = Field(examples=["2024-01-01T00:00:00Z"])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "plan_type": "PRO",
                    "feeds_limit": 10,
                    "sources_per_feed_limit": 20,
                    "price_amount_micros": 4990000,
                    "is_active": True,
                    "created_at": "2024-01-01T00:00:00Z",
                }
            ]
        }
    )


class ValidateSubscriptionRequest(BaseModel):
    """Request to validate RuStore subscription."""

    package_name: str = Field(
        description="Application package name (e.g., com.example.app)",
        examples=["ru.infatium.makefeed", "com.example.app"],
    )
    subscription_id: str = Field(
        description="Product/subscription ID from RuStore Console",
        examples=["makefeed_pro_monthly", "premium_yearly"],
    )
    purchase_token: str = Field(
        description="Subscription token from RuStore SDK (format: invoiceId.userId)",
        examples=["INV123456789.USR987654321"],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "package_name": "ru.infatium.makefeed",
                    "subscription_id": "makefeed_pro_monthly",
                    "purchase_token": "INV123456789.USR987654321",
                }
            ]
        }
    )


class ValidateSubscriptionResponse(BaseModel):
    """Response from subscription validation."""

    success: bool = Field(examples=[True, False])
    subscription_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440002", None]
    )
    plan_type: SubscriptionPlanType | None = Field(
        default=None, examples=["PRO", "FREE", None]
    )
    status: SubscriptionStatus | None = Field(
        default=None, examples=["ACTIVE", "EXPIRED", None]
    )
    expiry_date: datetime | None = Field(
        default=None, examples=["2024-02-15T10:30:00Z", None]
    )
    message: str = Field(
        examples=["Subscription validated successfully", "Invalid purchase token"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "subscription_id": "550e8400-e29b-41d4-a716-446655440002",
                    "plan_type": "PRO",
                    "status": "ACTIVE",
                    "expiry_date": "2024-02-15T10:30:00Z",
                    "message": "Subscription validated successfully",
                }
            ]
        }
    )


class CurrentSubscriptionResponse(BaseModel):
    """Current subscription information for user."""

    has_active_subscription: bool = Field(examples=[True, False])
    plan: SubscriptionPlanResponse = Field(
        examples=[
            {
                "id": "550e8400-e29b-41d4-a716-446655440001",
                "plan_type": "PRO",
                "feeds_limit": 10,
                "sources_per_feed_limit": 20,
                "price_amount_micros": 4990000,
                "is_active": True,
                "created_at": "2024-01-01T00:00:00Z",
            }
        ]
    )
    active_feeds_count: int = Field(
        description="Current number of active feeds for the user",
        examples=[3, 0, 10],
    )
    subscription_id: UUID | None = Field(
        default=None, examples=["550e8400-e29b-41d4-a716-446655440002", None]
    )
    platform: SubscriptionPlatform | None = Field(
        default=None, examples=["RUSTORE", "APPSTORE", None]
    )
    start_date: datetime | None = Field(
        default=None, examples=["2024-01-15T10:30:00Z", None]
    )
    expiry_date: datetime | None = Field(
        default=None, examples=["2024-02-15T10:30:00Z", None]
    )
    is_auto_renewing: bool = Field(default=False, examples=[True, False])
    status: SubscriptionStatus | None = Field(
        default=None, examples=["ACTIVE", "EXPIRED", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "has_active_subscription": True,
                    "plan": {
                        "id": "550e8400-e29b-41d4-a716-446655440001",
                        "plan_type": "PRO",
                        "feeds_limit": 10,
                        "sources_per_feed_limit": 20,
                        "price_amount_micros": 4990000,
                        "is_active": True,
                        "created_at": "2024-01-01T00:00:00Z",
                    },
                    "active_feeds_count": 3,
                    "subscription_id": "550e8400-e29b-41d4-a716-446655440002",
                    "platform": "RUSTORE",
                    "start_date": "2024-01-15T10:30:00Z",
                    "expiry_date": "2024-02-15T10:30:00Z",
                    "is_auto_renewing": True,
                    "status": "ACTIVE",
                }
            ]
        }
    )


class SubscriptionWithLimitsResponse(BaseModel):
    """Subscription information with usage limits."""

    plan_type: SubscriptionPlanType = Field(examples=["PRO", "FREE"])
    feeds_limit: int = Field(examples=[10, 3, 50])
    sources_per_feed_limit: int = Field(examples=[20, 5, 100])
    has_active_subscription: bool = Field(examples=[True, False])
    expiry_date: datetime | None = Field(
        default=None, examples=["2024-02-15T10:30:00Z", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "plan_type": "PRO",
                    "feeds_limit": 10,
                    "sources_per_feed_limit": 20,
                    "has_active_subscription": True,
                    "expiry_date": "2024-02-15T10:30:00Z",
                }
            ]
        }
    )


class ManualSubscriptionRequest(BaseModel):
    """Request for manual subscription creation (admin)."""

    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440003"])
    months: int = Field(
        default=1, ge=1, description="Duration in months", examples=[1, 3, 12]
    )
    plan_type: SubscriptionPlanType = Field(
        default=SubscriptionPlanType.PRO,
        description="Subscription plan type",
        examples=["PRO"],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "user_id": "550e8400-e29b-41d4-a716-446655440003",
                    "months": 3,
                    "plan_type": "PRO",
                }
            ]
        }
    )


class ManualSubscriptionResponse(BaseModel):
    """Response for manual subscription creation."""

    success: bool = Field(examples=[True, False])
    subscription_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440004"])
    plan_type: SubscriptionPlanType = Field(examples=["PRO", "FREE"])
    status: SubscriptionStatus = Field(examples=["ACTIVE", "PENDING"])
    expiry_date: datetime = Field(examples=["2024-04-15T10:30:00Z"])
    message: str = Field(
        examples=[
            "Subscription created for 3 months",
            "Subscription extended successfully",
        ]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "subscription_id": "550e8400-e29b-41d4-a716-446655440004",
                    "plan_type": "PRO",
                    "status": "ACTIVE",
                    "expiry_date": "2024-04-15T10:30:00Z",
                    "message": "Subscription created for 3 months",
                }
            ]
        }
    )
