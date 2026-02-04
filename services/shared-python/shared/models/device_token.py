from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class RegisterDeviceTokenRequest(BaseModel):
    token: str = Field(
        ...,
        min_length=10,
        max_length=500,
        examples=[
            "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
            "dQw4w9WgXcQ:APA91bHxxxxxxxxxxxxxxxxxx",
        ],
    )
    platform: str = Field(..., pattern="^(ios|android)$", examples=["ios", "android"])
    device_id: str | None = Field(
        None, max_length=255, examples=["A1B2C3D4-E5F6-7890-ABCD-EF1234567890", None]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "token": "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
                    "platform": "ios",
                    "device_id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
                },
                {
                    "token": "dQw4w9WgXcQ:APA91bHxxxxxxxxxxxxxxxxxx",
                    "platform": "android",
                    "device_id": "android-device-123456",
                },
            ]
        }
    )


class RegisterDeviceTokenResponse(BaseModel):
    id: int = Field(examples=[42, 1, 100])
    user_id: UUID = Field(examples=["550e8400-e29b-41d4-a716-446655440001"])
    platform: str = Field(examples=["ios", "android"])
    created_at: datetime = Field(examples=["2024-01-15T10:30:00Z"])
    is_new: bool = Field(examples=[True, False])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": 42,
                    "user_id": "550e8400-e29b-41d4-a716-446655440001",
                    "platform": "ios",
                    "created_at": "2024-01-15T10:30:00Z",
                    "is_new": True,
                }
            ]
        }
    )


class UnregisterDeviceTokenRequest(BaseModel):
    token: str = Field(
        ...,
        min_length=10,
        max_length=500,
        examples=[
            "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
            "dQw4w9WgXcQ:APA91bHxxxxxxxxxxxxxxxxxx",
        ],
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"token": "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]"}]
        }
    )


class UnregisterDeviceTokenResponse(BaseModel):
    success: bool = Field(examples=[True, False])
    message: str = Field(
        examples=["Device token unregistered successfully", "Device token not found"]
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"success": True, "message": "Device token unregistered successfully"}
            ]
        }
    )
