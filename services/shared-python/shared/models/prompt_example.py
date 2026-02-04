"""Models for prompt examples."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class PromptExampleResponse(BaseModel):
    """Response model for a single prompt example."""

    id: UUID
    prompt: str
    tags: list[str]
    created_at: datetime

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "prompt": "Show me the latest AI research news with a focus on language models",
                    "tags": ["AI", "Research", "LLM"],
                    "created_at": "2024-01-15T10:30:00Z",
                }
            ]
        }
    )


class PromptExamplesListResponse(BaseModel):
    """Response model for list of prompt examples."""

    data: list[PromptExampleResponse]

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "data": [
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440001",
                            "prompt": "Show me the latest AI research news",
                            "tags": ["AI", "Research"],
                            "created_at": "2024-01-15T10:30:00Z",
                        },
                        {
                            "id": "550e8400-e29b-41d4-a716-446655440002",
                            "prompt": "Daily digest of crypto market updates",
                            "tags": ["Crypto", "Finance"],
                            "created_at": "2024-01-14T09:00:00Z",
                        },
                    ]
                }
            ]
        }
    )
