import pytest
from conftest import wait_for_posts


def test_digest_appears_within_sla(api, digest_feed):
    posts, elapsed = wait_for_posts(api, digest_feed, min_posts=1, timeout=90, interval=3)
    assert len(posts) > 0, f"No digest post within 90s SLA (waited {elapsed}s)"


def test_digest_has_title(api, digest_feed):
    posts, _ = wait_for_posts(api, digest_feed, min_posts=1, timeout=90, interval=3)
    if not posts:
        pytest.skip("No digest post appeared")
    assert posts[0].get("title"), "Digest post has no title"


def test_digest_has_views(api, digest_feed):
    posts, _ = wait_for_posts(api, digest_feed, min_posts=1, timeout=90, interval=3)
    if not posts:
        pytest.skip("No digest post appeared")
    assert posts[0].get("views"), "Digest post has no views"
