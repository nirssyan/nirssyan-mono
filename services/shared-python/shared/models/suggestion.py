"""Pydantic models for suggestions."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SuggestionResponse(BaseModel):
    """Response model for a localized suggestion."""

    id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    name: dict[str, str] = Field(examples=[{"en": "Technology", "ru": "Технологии"}])
    source_type: str | None = Field(
        default=None,
        examples=["TELEGRAM"],
        description="Source type for source suggestions: TELEGRAM, WEBSITE",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "name": {"en": "Technology", "ru": "Технологии"},
                    "source_type": None,
                }
            ]
        }
    )
