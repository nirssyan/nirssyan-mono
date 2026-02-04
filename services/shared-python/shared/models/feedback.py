from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class CreateFeedbackResponse(BaseModel):
    """Response model for feedback creation."""

    success: bool = Field(
        description="Whether feedback was created successfully", examples=[True, False]
    )
    message: str = Field(
        description="Status message",
        examples=["Feedback submitted successfully", "Failed to submit feedback"],
    )
    feedback_id: UUID = Field(
        description="UUID of created feedback",
        examples=["550e8400-e29b-41d4-a716-446655440001"],
    )
    images_count: int = Field(
        description="Number of images uploaded", ge=0, le=5, examples=[0, 2, 5]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "success": True,
                    "message": "Feedback submitted successfully",
                    "feedback_id": "550e8400-e29b-41d4-a716-446655440001",
                    "images_count": 2,
                }
            ]
        }
    )
