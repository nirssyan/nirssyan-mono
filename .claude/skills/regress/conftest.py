import subprocess
import time
import os
import re
import json

import httpx
import jwt
import pytest
from pathlib import Path

pytest_plugins = ["plugin_telegram"]

SKILL_DIR = Path(__file__).parent


def load_env():
    env_file = SKILL_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


load_env()


def pytest_addoption(parser):
    parser.addoption("--env", default=os.environ.get("ENV", "dev"), choices=["dev", "prod"])
    parser.addoption("--tg-report", action="store_true", default=True, dest="tg_report")
    parser.addoption("--no-tg-report", action="store_false", dest="tg_report")


@pytest.fixture(scope="session")
def env(request):
    return request.config.getoption("--env")


@pytest.fixture(scope="session")
def base_url(env):
    return "https://api.infatium.ru" if env == "prod" else "https://dev.api.infatium.ru"


@pytest.fixture(scope="session")
def namespace(env):
    return "infatium-prod" if env == "prod" else "infatium-dev"


@pytest.fixture(scope="session")
def jwt_secret(namespace):
    kubeconfig = os.environ.get("KUBECONFIG", "~/.kube/nirssyan-infra.kubeconfig")
    result = subprocess.run(
        f"KUBECONFIG={kubeconfig} kubectl get secret auth-secrets -n {namespace} "
        f"-o jsonpath='{{.data.JWT_SECRET}}' | base64 -d",
        shell=True, capture_output=True, text=True,
    )
    secret = result.stdout.strip()
    if not secret:
        result = subprocess.run(
            f"KUBECONFIG={kubeconfig} kubectl get secret service-secrets -n {namespace} "
            f"-o jsonpath='{{.data.SUPABASE_JWT_SECRET}}' | base64 -d",
            shell=True, capture_output=True, text=True,
        )
        secret = result.stdout.strip()
    assert secret, "Could not get JWT_SECRET from k8s"
    return secret


@pytest.fixture(scope="session")
def jwt_token(jwt_secret):
    now = int(time.time())
    user_id = os.environ["USER_ID"]
    payload = {
        "iss": "auth-service",
        "sub": user_id,
        "uid": user_id,
        "aud": ["makefeed-api"],
        "email": os.environ["EMAIL"],
        "iat": now,
        "exp": now + 3600,
        "jti": f"regress-{now}",
    }
    return jwt.encode(payload, jwt_secret, algorithm="HS256")


@pytest.fixture(scope="session")
def api(base_url, jwt_token):
    with httpx.Client(
        base_url=base_url, verify=False, timeout=30.0,
        headers={"Authorization": f"Bearer {jwt_token}", "X-Dry-Run-Notify": "true"},
    ) as client:
        yield client


@pytest.fixture(scope="session")
def user_id():
    return os.environ["USER_ID"]


def kubectl_logs(namespace, deployment, since="5m"):
    kubeconfig = os.environ.get("KUBECONFIG", "~/.kube/nirssyan-infra.kubeconfig")
    r = subprocess.run(
        f"KUBECONFIG={kubeconfig} kubectl logs -n {namespace} deployment/{deployment} --since={since}",
        shell=True, capture_output=True, text=True,
    )
    return r.stdout.splitlines()


def kubectl_exec_sql(namespace, sql):
    kubeconfig = os.environ.get("KUBECONFIG", "~/.kube/nirssyan-infra.kubeconfig")
    r = subprocess.run(
        f"KUBECONFIG={kubeconfig} kubectl exec -n {namespace} postgres-0 -- "
        f"psql -U postgres -d postgres -t -c \"{sql}\"",
        shell=True, capture_output=True, text=True,
    )
    return r.stdout.strip()


def wait_for_posts(api, feed_id, *, min_posts=1, timeout=45, interval=2):
    start = time.time()
    while time.time() - start < timeout:
        resp = api.get(f"/posts/feed/{feed_id}", params={"limit": 10})
        if resp.status_code == 200:
            posts = resp.json().get("posts", [])
            if len(posts) >= min_posts:
                return posts, round(time.time() - start, 1)
        time.sleep(interval)
    return [], round(time.time() - start, 1)


@pytest.fixture(scope="session")
def view_id(api):
    resp = api.get("/suggestions/views")
    if resp.status_code == 200:
        views = resp.json()
        if views:
            return views[0]["id"]
    return None


@pytest.fixture(scope="session")
def single_feed(api, view_id):
    """Single shared SINGLE_POST feed for all tests."""
    ts = time.strftime("%Y%m%d_%H%M%S")
    body = {
        "name": f"Regress Single {ts}",
        "sources": [{"url": "@rbc_news", "type": "TELEGRAM"}],
        "feed_type": "SINGLE_POST",
    }
    if view_id:
        body["views_raw"] = [view_id]

    resp = api.post("/feeds/create", json=body)
    assert resp.status_code in (200, 201), f"Feed create failed: {resp.status_code} {resp.text[:200]}"

    data = resp.json()
    feed_id = data.get("feed_id") or data.get("data", {}).get("id")
    assert feed_id, f"No feed_id in response: {data}"

    yield {"id": feed_id, "view_id": view_id}

    api.delete("/users_feeds", params={"feed_id": feed_id})


@pytest.fixture(scope="session")
def single_feed_posts(api, single_feed):
    """Wait for posts in the shared single feed."""
    posts, elapsed = wait_for_posts(api, single_feed["id"], min_posts=1, timeout=45)
    return posts


@pytest.fixture(scope="session")
def digest_feed(api):
    """Single shared DIGEST feed for all tests."""
    ts = time.strftime("%Y%m%d_%H%M%S")
    body = {
        "name": f"Regress Digest {ts}",
        "sources": [{"url": "@rbc_news", "type": "TELEGRAM"}],
        "feed_type": "DIGEST",
    }
    resp = api.post("/feeds/create", json=body)
    assert resp.status_code in (200, 201), f"Digest feed create failed: {resp.status_code} {resp.text[:200]}"

    data = resp.json()
    feed_id = data.get("feed_id") or data.get("data", {}).get("id")
    assert feed_id, f"No feed_id in response: {data}"

    yield feed_id

    api.delete("/users_feeds", params={"feed_id": feed_id})


@pytest.fixture(scope="session", autouse=True)
def pre_cleanup(api, namespace, user_id):
    kubectl_exec_sql(
        namespace,
        f"DELETE FROM users_feeds uf WHERE uf.user_id = '{user_id}' "
        f"AND NOT EXISTS (SELECT 1 FROM feeds f WHERE f.id = uf.feed_id)",
    )

    resp = api.get("/feeds")
    if resp.status_code == 200:
        data = resp.json()
        feeds = data if isinstance(data, list) else data.get("feeds", data.get("data", []))
        for f in feeds:
            if f.get("name", "").startswith("Regress"):
                api.delete("/users_feeds", params={"feed_id": f["id"]})
