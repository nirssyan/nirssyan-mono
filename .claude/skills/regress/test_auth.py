import time

import httpx
import jwt as pyjwt
import pytest

DEMO_EMAIL = "demo@infatium.ru"
DEMO_PASSWORD = "QLjegxHXOWIczmpMoYk#D2RY7QhFv!j5"


@pytest.fixture(scope="module")
def auth_tokens(base_url):
    time.sleep(1)
    with httpx.Client(base_url=base_url, verify=False, timeout=30.0) as client:
        resp = client.post("/auth/demo-login", json={"email": DEMO_EMAIL, "password": DEMO_PASSWORD})
        if resp.status_code == 404:
            pytest.skip("demo-login not available (DEMO_MODE_ENABLED=false)")
        assert resp.status_code == 200, f"demo-login failed: {resp.status_code} {resp.text}"
        data = resp.json()
        yield {
            "access_token": data["access_token"],
            "refresh_token": data["refresh_token"],
            "user": data.get("user", {}),
            "client": client,
        }


def test_demo_login_returns_tokens(auth_tokens):
    assert auth_tokens["access_token"]
    assert auth_tokens["refresh_token"]
    assert auth_tokens["user"].get("id")


def test_demo_login_validation(base_url):
    """Test invalid login attempts with delays to avoid rate limiting."""
    with httpx.Client(base_url=base_url, verify=False, timeout=10.0) as c:
        resp = c.post("/auth/demo-login", json={})
        if resp.status_code == 404:
            pytest.skip("demo-login not available (DEMO_MODE_ENABLED=false)")
        assert resp.status_code in (400, 422), f"missing email: expected 400/422, got {resp.status_code}"

        time.sleep(0.5)

        resp = c.post("/auth/demo-login", json={"email": "unknown@example.com", "password": "wrong"})
        assert resp.status_code in (401, 403), f"wrong creds: expected 401/403, got {resp.status_code}"


def test_access_token_works(base_url, auth_tokens):
    resp = auth_tokens["client"].get(
        "/feeds",
        headers={"Authorization": f"Bearer {auth_tokens['access_token']}"},
    )
    assert resp.status_code == 200


def test_expired_token_rejected(base_url, jwt_secret):
    now = int(time.time())
    token = pyjwt.encode(
        {"sub": "00000000-0000-0000-0000-000000000000", "iat": now - 7200, "exp": now - 3600},
        jwt_secret,
        algorithm="HS256",
    )
    with httpx.Client(base_url=base_url, verify=False, timeout=10.0) as c:
        resp = c.get("/feeds", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401


def test_invalid_token_rejected(base_url):
    with httpx.Client(base_url=base_url, verify=False, timeout=10.0) as c:
        resp = c.get("/feeds", headers={"Authorization": "Bearer garbage-string"})
    assert resp.status_code == 401


def test_missing_auth_rejected(base_url):
    with httpx.Client(base_url=base_url, verify=False, timeout=10.0) as c:
        resp = c.get("/feeds")
    assert resp.status_code == 401


def test_refresh_returns_new_tokens(auth_tokens):
    resp = auth_tokens["client"].post(
        "/auth/refresh",
        json={"refresh_token": auth_tokens["refresh_token"]},
    )
    assert resp.status_code == 200, f"refresh failed: {resp.status_code} {resp.text}"
    data = resp.json()
    assert data["access_token"]
    assert data["refresh_token"]
    auth_tokens["access_token"] = data["access_token"]
    auth_tokens["refresh_token"] = data["refresh_token"]


def test_new_access_token_works(base_url, auth_tokens):
    resp = auth_tokens["client"].get(
        "/feeds",
        headers={"Authorization": f"Bearer {auth_tokens['access_token']}"},
    )
    assert resp.status_code == 200


def test_refresh_missing_token(base_url):
    with httpx.Client(base_url=base_url, verify=False, timeout=10.0) as c:
        resp = c.post("/auth/refresh", json={})
    assert resp.status_code == 400


def test_logout_succeeds(auth_tokens):
    resp = auth_tokens["client"].post(
        "/auth/logout",
        json={"refresh_token": auth_tokens["refresh_token"]},
    )
    assert resp.status_code == 200


def test_refresh_after_logout_fails(auth_tokens):
    resp = auth_tokens["client"].post(
        "/auth/refresh",
        json={"refresh_token": auth_tokens["refresh_token"]},
    )
    assert resp.status_code == 401
