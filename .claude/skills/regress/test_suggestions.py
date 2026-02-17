def test_views_available(api):
    resp = api.get("/suggestions/views")
    assert resp.status_code == 200
    views = resp.json()
    assert len(views) > 0, "No views available"


def test_telegram_sources_available(api):
    resp = api.get("/suggestions/sources")
    assert resp.status_code == 200
    sources = resp.json()
    tg_sources = [s for s in sources if s.get("source_type") == "TELEGRAM"]
    assert len(tg_sources) > 0, "No Telegram sources available"
