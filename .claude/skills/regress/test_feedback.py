import os
import httpx
import pytest
from conftest import kubectl_logs


def test_feedback_submission(api):
    resp = api.post("/feedback", files={"message": (None, "Regress test feedback - please ignore")})
    assert resp.status_code == 200, f"Feedback failed: {resp.status_code} {resp.text[:200]}"
    data = resp.json()
    assert data.get("success"), f"Feedback not successful: {data}"
    assert data.get("feedback_id"), f"No feedback_id: {data}"


def test_empty_feedback_rejected(api):
    resp = api.post("/feedback", files={"message": (None, "")})
    assert resp.status_code == 400, f"Empty feedback should be rejected, got {resp.status_code}"


def test_go_api_errors_acceptable(namespace):
    lines = kubectl_logs(namespace, "app-api-go", since="5m")
    errors = [l for l in lines if '"level":"error"' in l]
    assert len(errors) < 5, f"go-api has {len(errors)} errors in last 5m"


def test_processor_errors_acceptable(namespace):
    lines = kubectl_logs(namespace, "worker-processor-go", since="5m")
    errors = [l for l in lines if '"level":"error"' in l]
    assert len(errors) < 5, f"processor has {len(errors)} errors in last 5m"


def test_glitchtip_reachable():
    token = os.environ.get("GLITCHTIP_TOKEN")
    if not token:
        pytest.skip("GLITCHTIP_TOKEN not set")
    resp = httpx.get(
        "https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/",
        headers={"Authorization": f"Bearer {token}"},
        params={"limit": 5},
        verify=False, timeout=10.0,
    )
    assert resp.status_code == 200, f"GlitchTip unreachable: {resp.status_code}"
