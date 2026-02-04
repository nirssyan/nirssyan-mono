from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import device_tokens


class DeviceTokenRepository:
    async def register_token(
        self,
        conn: AsyncConnection,
        user_id: UUID,
        token: str,
        platform: str,
        device_id: str | None = None,
    ) -> dict[str, Any]:
        now = datetime.now(timezone.utc)
        stmt = pg_insert(device_tokens).values(
            user_id=user_id,
            token=token,
            platform=platform,
            device_id=device_id,
            is_active=True,
            updated_at=now,
        )
        stmt = stmt.on_conflict_do_update(
            constraint="device_tokens_token_key",
            set_={
                "user_id": user_id,
                "platform": platform,
                "device_id": device_id,
                "is_active": True,
                "updated_at": now,
            },
        ).returning(device_tokens)

        result = await conn.execute(stmt)
        row = result.fetchone()
        if row is None:
            raise ValueError("Failed to register device token")

        return dict(row._mapping)

    async def unregister_token(self, conn: AsyncConnection, token: str) -> bool:
        now = datetime.now(timezone.utc)
        stmt = (
            update(device_tokens)
            .where(device_tokens.c.token == token)
            .values(is_active=False, updated_at=now)
        )
        result = await conn.execute(stmt)
        return result.rowcount > 0

    async def delete_token(self, conn: AsyncConnection, token: str) -> bool:
        stmt = delete(device_tokens).where(device_tokens.c.token == token)
        result = await conn.execute(stmt)
        return result.rowcount > 0

    async def get_active_tokens_for_user(
        self, conn: AsyncConnection, user_id: UUID
    ) -> list[dict[str, Any]]:
        stmt = (
            select(device_tokens)
            .where(device_tokens.c.user_id == user_id)
            .where(device_tokens.c.is_active == True)  # noqa: E712
        )
        result = await conn.execute(stmt)
        return [dict(row._mapping) for row in result.fetchall()]
