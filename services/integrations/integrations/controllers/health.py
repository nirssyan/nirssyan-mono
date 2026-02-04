"""Health check controller."""

from litestar import Controller, get


class HealthController(Controller):
    """Health check endpoints."""

    path = "/healthz"
    tags = ["Health"]

    @get("/", status_code=200)
    async def health_check(self) -> dict[str, str]:
        """Health check endpoint for Kubernetes probes."""
        return {"status": "ok"}
