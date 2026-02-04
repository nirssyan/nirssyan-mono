from pydantic import BaseModel, ConfigDict


class DeleteUserResponse(BaseModel):
    """Response model for user deletion operations"""

    user_id: str
    deleted_feeds: int
    cancelled_subscriptions: int
    deleted_chats: int
    deleted_tags: int
    deleted_posts_seen: int
    deleted_feedbacks: int
    message: str = "User successfully deleted"

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "user_id": "550e8400-e29b-41d4-a716-446655440000",
                    "deleted_feeds": 3,
                    "cancelled_subscriptions": 1,
                    "deleted_chats": 5,
                    "deleted_tags": 12,
                    "deleted_posts_seen": 847,
                    "deleted_feedbacks": 2,
                    "message": "User successfully deleted",
                }
            ]
        }
    )
