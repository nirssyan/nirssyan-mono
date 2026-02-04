from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SourceValidationRequest(BaseModel):
    """Request model for source validation."""

    source: str = Field(
        description="Source string to validate (Telegram channel or URL)",
        examples=["@TechNewsChannel", "https://techcrunch.com/feed/"],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"source": "@TechNewsChannel"},
                {"source": "https://techcrunch.com/feed/"},
            ]
        }
    )


class SourceValidationResponse(BaseModel):
    """Response model for source validation."""

    is_valid: bool = Field(
        description="Whether the source is valid", examples=[True, False]
    )
    source_type: Literal["TELEGRAM", "WEBSITE"] | None = Field(
        default=None,
        description="Type of source",
        examples=["TELEGRAM", "WEBSITE", None],
    )
    detected_type: str | None = Field(
        default=None,
        description="Detected source type (RSS_FEEDPARSER, HTML, TELEGRAM)",
        examples=["RSS_FEEDPARSER", "HTML", "TELEGRAM", None],
    )
    short_name: str | None = Field(
        default=None,
        description="Short name (username for TG, domain for website)",
        examples=["TechNewsChannel", "techcrunch.com", None],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "is_valid": True,
                    "source_type": "TELEGRAM",
                    "detected_type": "TELEGRAM",
                    "short_name": "TechNewsChannel",
                },
                {
                    "is_valid": True,
                    "source_type": "WEBSITE",
                    "detected_type": "RSS_FEEDPARSER",
                    "short_name": "techcrunch.com",
                },
                {
                    "is_valid": False,
                    "source_type": None,
                    "detected_type": None,
                    "short_name": None,
                },
            ]
        }
    )
