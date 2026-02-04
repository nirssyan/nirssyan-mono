"""Repository for subscription operations."""

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import (
    subscription_plans,
    subscription_transactions,
    user_subscriptions,
)
from shared.enums import (
    SubscriptionPlanType,
    SubscriptionStatus,
    TransactionType,
)


class SubscriptionRepository:
    """Repository for subscription database operations."""

    async def get_plan_by_type(
        self, conn: AsyncConnection, plan_type: SubscriptionPlanType
    ) -> dict[str, Any] | None:
        """Get subscription plan by plan type.

        Args:
            conn: Database connection
            plan_type: Plan type (FREE or PRO)

        Returns:
            Plan data dict or None if not found
        """
        query = select(subscription_plans).where(
            subscription_plans.c.plan_type == plan_type
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def get_active_subscription(
        self, conn: AsyncConnection, user_id: UUID
    ) -> dict[str, Any] | None:
        """Get active subscription for user.

        Args:
            conn: Database connection
            user_id: User UUID

        Returns:
            Subscription data dict or None if no active subscription
        """
        query = (
            select(user_subscriptions)
            .where(user_subscriptions.c.user_id == user_id)
            .where(user_subscriptions.c.status == SubscriptionStatus.ACTIVE)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def get_active_subscription_with_plan(
        self, conn: AsyncConnection, user_id: UUID
    ) -> dict[str, Any] | None:
        """Get active subscription with plan details.

        Args:
            conn: Database connection
            user_id: User UUID

        Returns:
            Dict with subscription and plan data, or None
        """
        query = (
            select(
                user_subscriptions,
                subscription_plans,
            )
            .select_from(
                user_subscriptions.join(
                    subscription_plans,
                    user_subscriptions.c.subscription_plan_id
                    == subscription_plans.c.id,
                )
            )
            .where(user_subscriptions.c.user_id == user_id)
            .where(user_subscriptions.c.status == SubscriptionStatus.ACTIVE)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None

    async def create_subscription(
        self,
        conn: AsyncConnection,
        user_id: UUID,
        subscription_plan_id: UUID,
        platform: str,
        platform_subscription_id: str,
        platform_order_id: str,
        start_date: datetime,
        expiry_date: datetime,
        is_auto_renewing: bool,
        status: SubscriptionStatus,
    ) -> dict[str, Any]:
        """Create new subscription.

        Args:
            conn: Database connection
            user_id: User UUID
            subscription_plan_id: Plan UUID
            platform: Platform (RUSTORE, GOOGLE_PLAY, APPLE)
            platform_subscription_id: Platform purchase token
            platform_order_id: Platform order ID
            start_date: Subscription start date
            expiry_date: Subscription expiry date
            is_auto_renewing: Auto-renewal status
            status: Subscription status

        Returns:
            Created subscription data dict
        """
        query = (
            user_subscriptions.insert()
            .values(
                user_id=user_id,
                subscription_plan_id=subscription_plan_id,
                platform=platform,
                platform_subscription_id=platform_subscription_id,
                platform_order_id=platform_order_id,
                start_date=start_date,
                expiry_date=expiry_date,
                is_auto_renewing=is_auto_renewing,
                status=status,
            )
            .returning(user_subscriptions)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to create subscription")
        return dict(row._mapping)

    async def update_subscription_status(
        self,
        conn: AsyncConnection,
        subscription_id: UUID,
        status: SubscriptionStatus,
        expiry_date: datetime | None = None,
        is_auto_renewing: bool | None = None,
    ) -> dict[str, Any]:
        """Update subscription status.

        Args:
            conn: Database connection
            subscription_id: Subscription UUID
            status: New status
            expiry_date: Optional new expiry date
            is_auto_renewing: Optional new auto-renewal status

        Returns:
            Updated subscription data dict
        """
        values = {"status": status, "updated_at": datetime.now(timezone.utc)}
        if expiry_date is not None:
            values["expiry_date"] = expiry_date
        if is_auto_renewing is not None:
            values["is_auto_renewing"] = is_auto_renewing

        query = (
            user_subscriptions.update()
            .where(user_subscriptions.c.id == subscription_id)
            .values(**values)
            .returning(user_subscriptions)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError(f"Subscription {subscription_id} not found")
        return dict(row._mapping)

    async def get_expiring_subscriptions(
        self, conn: AsyncConnection, before_date: datetime
    ) -> list[dict[str, Any]]:
        """Get subscriptions expiring before given date.

        Args:
            conn: Database connection
            before_date: Date to check against

        Returns:
            List of expiring subscriptions
        """
        query = (
            select(user_subscriptions)
            .where(user_subscriptions.c.status == SubscriptionStatus.ACTIVE)
            .where(user_subscriptions.c.expiry_date < before_date)
        )
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]

    async def create_transaction(
        self,
        conn: AsyncConnection,
        user_subscription_id: UUID | None,
        transaction_type: TransactionType,
        platform_response: dict | None = None,
        is_sandbox: bool = False,
    ) -> dict[str, Any]:
        """Create subscription transaction record.

        Args:
            conn: Database connection
            user_subscription_id: Subscription UUID (can be None for failed validations)
            transaction_type: Type of transaction
            platform_response: Platform API response (JSON)
            is_sandbox: Whether this is a sandbox/test transaction

        Returns:
            Created transaction data dict
        """
        query = (
            subscription_transactions.insert()
            .values(
                user_subscription_id=user_subscription_id,
                transaction_type=transaction_type,
                platform_response=platform_response,
                is_sandbox=is_sandbox,
            )
            .returning(subscription_transactions)
        )
        result = await conn.execute(query)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to create transaction")
        return dict(row._mapping)

    async def get_subscription_by_platform_id(
        self, conn: AsyncConnection, platform_subscription_id: str
    ) -> dict[str, Any] | None:
        """Get subscription by platform subscription ID.

        Args:
            conn: Database connection
            platform_subscription_id: Platform purchase token

        Returns:
            Subscription data dict or None
        """
        query = select(user_subscriptions).where(
            user_subscriptions.c.platform_subscription_id == platform_subscription_id
        )
        result = await conn.execute(query)
        row = result.fetchone()
        return dict(row._mapping) if row else None
