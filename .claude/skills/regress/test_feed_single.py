import time
import pytest
from conftest import wait_for_posts, kubectl_logs


def test_first_post_within_sla(api, single_feed):
    _, elapsed = wait_for_posts(api, single_feed["id"], min_posts=1, timeout=45)
    resp = api.get(f"/posts/feed/{single_feed['id']}", params={"limit": 1})
    posts = resp.json().get("posts", [])
    assert len(posts) > 0, f"No posts appeared within 45s SLA (waited {elapsed}s)"


def test_posts_have_titles(single_feed_posts):
    assert single_feed_posts, "No posts to check"
    titled = [p for p in single_feed_posts if p.get("title")]
    assert len(titled) > 0, "No posts have titles"


def test_posts_have_views(single_feed_posts):
    assert single_feed_posts, "No posts to check"
    with_views = [p for p in single_feed_posts if p.get("views")]
    assert len(with_views) > 0, "No posts have views"


def test_posts_have_sources(single_feed_posts):
    assert single_feed_posts, "No posts to check"
    with_sources = [p for p in single_feed_posts if p.get("sources")]
    assert len(with_sources) > 0, "No posts have sources"


@pytest.fixture(scope="module")
def summarize_result(api, single_feed, single_feed_posts):
    assert single_feed_posts, "No posts to summarize"
    resp = api.post(f"/feeds/summarize_unseen/{single_feed['id']}", timeout=60.0)
    assert resp.status_code == 201, f"Summarize failed: {resp.status_code} {resp.text[:300]}"
    return resp.json()


def test_summarize_creates_digest_post(summarize_result):
    assert summarize_result.get("id"), "Digest post has no id"
    assert summarize_result.get("views"), "Digest post has no views"


def test_summarize_digest_has_title(summarize_result):
    assert summarize_result.get("title"), "Digest post has no title"


def test_summarize_digest_has_media(single_feed_posts, summarize_result):
    source_media = []
    for p in single_feed_posts:
        mo = p.get("media_objects") or []
        source_media.extend(mo)
    if not source_media:
        pytest.skip("Source posts have no media — nothing to aggregate")
    digest_media = summarize_result.get("media_objects") or []
    assert len(digest_media) > 0, "Digest post has no media_objects despite source posts having media"
    source_urls = {m["url"] for m in source_media if "url" in m}
    digest_urls = {m["url"] for m in digest_media if "url" in m}
    assert source_urls == digest_urls, (
        f"Media mismatch: source has {len(source_urls)} urls, digest has {len(digest_urls)} urls. "
        f"Missing in digest: {source_urls - digest_urls}"
    )


def test_summarize_digest_has_image_url(single_feed_posts, summarize_result):
    has_photos = any(
        mo.get("type") in ("photo", "image")
        for p in single_feed_posts
        for mo in (p.get("media_objects") or [])
    )
    if not has_photos:
        pytest.skip("Source posts have no photos")
    assert summarize_result.get("image_url"), "Digest post has no image_url despite source posts having photos"


def test_summarize_marks_posts_as_read(api, single_feed, summarize_result):
    resp = api.post(f"/feeds/summarize_unseen/{single_feed['id']}", timeout=60.0)
    assert resp.status_code in (404, 201), (
        f"Expected 404 (no unseen) or 201 (new posts arrived), got {resp.status_code}"
    )


def test_notifications_suppressed(namespace):
    """Verify that feed creation logged dry-run instead of sending TG."""
    lines = kubectl_logs(namespace, "app-api-go", since="3m")
    dry_run_lines = [l for l in lines if "dry-run" in l and "suppressed" in l]
    assert len(dry_run_lines) > 0, "No dry-run notification logs found"


def test_patch_views_filters_transformed(api, single_feed):
    """PATCH views/filters should be transformed asynchronously via go-processor."""
    feed_id = single_feed["id"]
    patch_resp = api.patch(
        f"/feeds/{feed_id}",
        json={"filters_raw": ["Убрать рекламу и спам"]},
    )
    assert patch_resp.status_code == 200, f"PATCH failed: {patch_resp.status_code} {patch_resp.text[:200]}"

    for attempt in range(15):
        time.sleep(3)
        modal_resp = api.get(f"/modal/feed/{feed_id}")
        assert modal_resp.status_code == 200
        data = modal_resp.json()
        filters = data.get("filters") or []
        if not filters:
            continue
        if isinstance(filters[0], dict) and "name" in filters[0] and "prompt" in filters[0]:
            assert filters[0]["name"].get("en") or filters[0]["name"].get("ru"), \
                f"Filter name missing localization: {filters[0]}"
            return

    pytest.fail(
        f"Filters not transformed within 45s. Last filters: {filters}"
    )
