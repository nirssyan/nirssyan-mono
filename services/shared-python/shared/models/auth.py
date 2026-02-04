from typing import Any

from pydantic import BaseModel


class DemoLoginRequest(BaseModel):
    email: str


class SupabaseUser(BaseModel):
    id: str
    aud: str
    role: str
    email: str
    email_confirmed_at: str | None = None
    phone: str = ""
    confirmed_at: str | None = None
    last_sign_in_at: str | None = None
    app_metadata: dict[str, Any] = {}
    user_metadata: dict[str, Any] = {}
    identities: list[Any] = []
    created_at: str | None = None
    updated_at: str | None = None
    is_anonymous: bool = False


class DemoLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    expires_at: int
    user: SupabaseUser
