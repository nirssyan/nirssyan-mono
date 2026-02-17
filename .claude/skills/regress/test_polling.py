import re
import pytest
from conftest import kubectl_logs


def test_telegram_poller_active(namespace):
    lines = kubectl_logs(namespace, "worker-poller-go", since="5m")
    tg_cycles = [l for l in lines if "Telegram poll cycle complete" in l]
    total_success = 0
    for c in tg_cycles[-5:]:
        m = re.search(r'"success":(\d+)', c)
        if m:
            total_success += int(m.group(1))
    assert total_success > 0, f"No successful Telegram polls in last 5m ({len(tg_cycles)} cycles found)"


@pytest.mark.skip(reason="No RSS sources active in dev")
def test_rss_poller_active(namespace):
    lines = kubectl_logs(namespace, "worker-poller-go", since="60m")
    rss_lines = [l for l in lines if "rss" in l.lower() or "RSS" in l]
    assert len(rss_lines) > 0, "No RSS poller logs in last 60m — service may not be running RSS polling"


def test_processor_errors_below_threshold(namespace):
    lines = kubectl_logs(namespace, "worker-processor-go", since="5m")
    errors = [l for l in lines if '"level":"error"' in l]
    assert len(errors) < 5, f"Processor has {len(errors)} errors in last 5m"
