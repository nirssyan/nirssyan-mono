import asyncio
import json
import ssl
import time
import threading

import pytest
import websockets


@pytest.fixture(scope="module")
def ws_session(base_url, jwt_token, api, view_id):
    """Connect WS first, then create a feed and collect events."""
    ws_url = base_url.replace("https://", "wss://").replace("http://", "ws://")
    ws_url = f"{ws_url}/ws/feeds?token={jwt_token}"

    events = []
    connected = threading.Event()
    stop = threading.Event()

    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    def ws_listener():
        async def _listen():
            try:
                async with websockets.connect(ws_url, ssl=ssl_ctx) as ws:
                    connected.set()
                    while not stop.is_set():
                        try:
                            msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
                            events.append(json.loads(msg))
                        except asyncio.TimeoutError:
                            continue
                        except websockets.ConnectionClosed:
                            break
            except Exception as e:
                connected.set()

        asyncio.run(_listen())

    t = threading.Thread(target=ws_listener, daemon=True)
    t.start()

    if not connected.wait(timeout=10):
        stop.set()
        t.join(timeout=3)
        yield {"connected": False, "feed_id": None, "events": [], "elapsed": 0}
        return

    body = {
        "name": f"Regress WS {time.strftime('%H%M%S')}",
        "sources": [{"url": "@rbc_news", "type": "TELEGRAM"}],
        "feed_type": "SINGLE_POST",
    }
    if view_id:
        body["views_raw"] = [view_id]

    create_time = time.time()
    resp = api.post("/feeds/create", json=body)
    assert resp.status_code in (200, 201), f"Feed create failed: {resp.status_code} {resp.text[:200]}"

    data = resp.json()
    feed_id = data.get("feed_id") or data.get("data", {}).get("id")
    assert feed_id, f"No feed_id in response: {data}"

    deadline = time.time() + 45
    while time.time() < deadline:
        has_creation = any(
            e.get("type") == "feed_creation_finished" and e.get("feed_id") == feed_id
            for e in events
        )
        has_post = any(
            e.get("type") == "post_created" and e.get("feed_id") == feed_id
            for e in events
        )
        if has_creation and has_post:
            break
        time.sleep(1)

    elapsed = round(time.time() - create_time, 1)

    stop.set()
    t.join(timeout=5)

    feed_events = [e for e in events if e.get("feed_id") == feed_id]

    yield {
        "connected": True,
        "feed_id": feed_id,
        "events": feed_events,
        "all_events": events,
        "elapsed": elapsed,
    }

    api.delete("/users_feeds", params={"feed_id": feed_id})


def test_ws_connects(ws_session):
    """WebSocket connection to /ws/feeds succeeds."""
    assert ws_session["connected"], "WebSocket connection failed"


def test_ws_feed_creation_finished(ws_session):
    """WS receives feed_creation_finished after feed is created."""
    feed_id = ws_session["feed_id"]
    creation_events = [
        e for e in ws_session["events"]
        if e.get("type") == "feed_creation_finished"
    ]
    assert len(creation_events) == 1, (
        f"Expected 1 feed_creation_finished, got {len(creation_events)}: {creation_events}"
    )
    assert creation_events[0]["feed_id"] == feed_id


def test_ws_post_created(ws_session):
    """WS receives post_created events for the new feed."""
    post_events = [
        e for e in ws_session["events"]
        if e.get("type") == "post_created"
    ]
    assert len(post_events) >= 1, (
        f"Expected at least 1 post_created, got {len(post_events)}. "
        f"Elapsed: {ws_session['elapsed']}s"
    )
    for e in post_events:
        assert "post_id" in e, f"post_created missing post_id: {e}"


def test_ws_events_within_timeout(ws_session):
    """WS events arrive within 45s of feed creation."""
    assert ws_session["elapsed"] < 45, (
        f"Events took {ws_session['elapsed']}s (limit 45s)"
    )
