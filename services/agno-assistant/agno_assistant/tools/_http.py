import httpx

from agno_assistant.config import settings


def api_call(method: str, path: str, user_id: str, **kwargs) -> str:
    headers = {
        "Authorization": f"Bearer {settings.internal_service_token}",
        "X-On-Behalf-Of": user_id,
        "Content-Type": "application/json",
    }
    with httpx.Client(
        base_url=settings.api_base_url, timeout=30, headers=headers
    ) as client:
        resp = client.request(method, path, **kwargs)
        resp.raise_for_status()
        return resp.text
