import httpx

KNOWN_MEDIA = {
    "photo": "/media/tg/photo/5222014757278258066_4709379097498213808?chat=1099860397&msg=142683",
    "photo2": "/media/tg/photo/5222166086155965073_-1559134058535295473?chat=1099860397&msg=142684",
    "video": "/media/tg/video/5188375482034326349_-8842147358190301942?chat=2378228292&msg=1678",
    "thumb": "/media/tg/photo/thumb_5188375482034326349_-8842147358190301942?chat=2378228292&msg=1678",
}


def test_photo_returns_200(base_url):
    url = f"{base_url}{KNOWN_MEDIA['photo']}"
    resp = httpx.get(url, verify=False, timeout=15.0, follow_redirects=True)
    assert resp.status_code == 200, f"Photo returned {resp.status_code}"
    assert len(resp.content) > 1000, f"Photo too small: {len(resp.content)}B"


def test_photo2_returns_200(base_url):
    url = f"{base_url}{KNOWN_MEDIA['photo2']}"
    resp = httpx.get(url, verify=False, timeout=15.0, follow_redirects=True)
    assert resp.status_code == 200, f"Photo2 returned {resp.status_code}"
    assert len(resp.content) > 1000, f"Photo2 too small: {len(resp.content)}B"


def test_video_returns_200(base_url):
    url = f"{base_url}{KNOWN_MEDIA['video']}"
    resp = httpx.get(url, verify=False, timeout=15.0, follow_redirects=True)
    assert resp.status_code == 200, f"Video returned {resp.status_code}"
    assert len(resp.content) > 10000, f"Video too small: {len(resp.content)}B"


def test_video_thumbnail_returns_200(base_url):
    url = f"{base_url}{KNOWN_MEDIA['thumb']}"
    resp = httpx.get(url, verify=False, timeout=15.0, follow_redirects=True)
    assert resp.status_code == 200, f"Thumbnail returned {resp.status_code}"
    assert len(resp.content) > 100, f"Thumbnail too small: {len(resp.content)}B"


