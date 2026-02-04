"""Repository for suggestions operations."""

from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncConnection

from shared.database.tables import suggestions


async def resolve_suggestion_uuids(
    conn: AsyncConnection, items: list[str]
) -> list[str]:
    """Replace suggestion UUIDs in a list with their localized text names."""
    uuids: dict[UUID, int] = {}
    for i, item in enumerate(items):
        try:
            uuids[UUID(item)] = i
        except ValueError:
            continue

    if not uuids:
        return items

    query = select(suggestions.c.id, suggestions.c.name).where(
        suggestions.c.id.in_(list(uuids.keys()))
    )
    result = await conn.execute(query)

    resolved = list(items)
    for row in result.fetchall():
        idx = uuids[row.id]
        name = row.name
        if isinstance(name, dict):
            resolved[idx] = name.get("en") or name.get("ru") or str(name)
        else:
            resolved[idx] = str(name)

    return resolved


class SuggestionRepository:
    """Repository for managing suggestions in the database."""

    async def get_by_type(
        self, conn: AsyncConnection, suggestion_type: str
    ) -> list[dict[str, Any]]:
        """Get suggestions by type with all localized names.

        Args:
            conn: Database connection
            suggestion_type: Type of suggestion (filter, view, source)

        Returns:
            List of suggestion dictionaries with id and name (JSONB dict with en/ru keys)
        """
        query = select(
            suggestions.c.id, suggestions.c.name, suggestions.c.source_type
        ).where(suggestions.c.type == suggestion_type)
        result = await conn.execute(query)
        return [dict(row._mapping) for row in result.fetchall()]
