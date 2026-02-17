import os
import re
import subprocess
import time
import traceback
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import httpx

BOT_TOKEN = os.environ.get("TG_BOT_TOKEN", "")
CHAT_ID = os.environ.get("TG_CHAT_ID", "-1002622491758")
THREAD_ID = int(os.environ.get("TG_THREAD_ID", "2057"))
TG_URL = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
MAX_MSG_LEN = 4096
USD_TO_RUB = 80

_LLM_RE = re.compile(
    r"LLM \| (\S+) \| (\d+)ms \| \$([0-9.]+) \| (\d+)→(\d+)"
)

AGENT_MODEL_KEYS = {
    "ViewGeneratorAgent": "VIEW_GENERATOR_MODEL",
    "PostTitleAgent": "POST_TITLE_MODEL",
    "ViewPromptTransformerAgent": "VIEW_PROMPT_TRANSFORMER_MODEL",
    "FeedSummaryAgent": "FEED_SUMMARY_MODEL",
    "UnseenSummaryAgent": "UNSEEN_SUMMARY_MODEL",
    "FactsExtractionAgent": "UNSEEN_SUMMARY_MODEL",
    "SynthesisAgent": "UNSEEN_SUMMARY_MODEL",
    "FeedFilterAgent": "FEED_FILTER_MODEL",
    "FeedTitleAgent": "FEED_TITLE_MODEL",
    "FeedDescriptionAgent": "FEED_DESCRIPTION_MODEL",
    "FeedTagsAgent": "FEED_TAGS_MODEL",
    "FeedCommentAgent": "FEED_COMMENT_MODEL",
    "ChatMessageAgent": "CHAT_MESSAGE_MODEL",
}


def _fetch_agent_models(namespace):
    kubeconfig = os.environ.get("KUBECONFIG", "~/.kube/nirssyan-infra.kubeconfig")
    r = subprocess.run(
        f"ssh -i ~/.ssh/id_infra_rsa -o StrictHostKeyChecking=no root@81.200.158.120 "
        f"\"kubectl get configmap worker-agents-python-config -n {namespace} -o json\"",
        shell=True, capture_output=True, text=True, timeout=15,
    )
    if r.returncode != 0 or not r.stdout.strip():
        return {}
    import json as _json
    try:
        data = _json.loads(r.stdout).get("data", {})
    except Exception:
        return {}
    models = {}
    for agent, key in AGENT_MODEL_KEYS.items():
        if key in data:
            val = data[key]
            short = val.rsplit("/", 1)[-1] if "/" in val else val
            models[agent] = short
    return models


def _fetch_llm_costs(namespace, start_utc):
    kubeconfig = os.environ.get("KUBECONFIG", "~/.kube/nirssyan-infra.kubeconfig")
    since_s = max(1, int((datetime.now(timezone.utc) - start_utc).total_seconds()) + 5)
    r = subprocess.run(
        f"KUBECONFIG={kubeconfig} kubectl logs -n {namespace} "
        f"deployment/worker-agents-python --since={since_s}s 2>/dev/null "
        f"| grep 'LLM |'",
        shell=True, capture_output=True, text=True, timeout=15,
    )
    if not r.stdout.strip():
        return []
    agg = defaultdict(lambda: {"cost_usd": 0.0, "prompt_tokens": 0, "completion_tokens": 0, "calls": 0})
    for line in r.stdout.splitlines():
        m = _LLM_RE.search(line)
        if not m:
            continue
        agent, _, cost, prompt_tok, compl_tok = m.groups()
        d = agg[agent]
        d["cost_usd"] += float(cost)
        d["prompt_tokens"] += int(prompt_tok)
        d["completion_tokens"] += int(compl_tok)
        d["calls"] += 1
    rows = []
    for agent, d in sorted(agg.items(), key=lambda x: x[1]["cost_usd"], reverse=True):
        rows.append({"agent": agent, **d})
    return rows


def _format_cost_section(cost_rows, agent_models=None):
    if not cost_rows:
        return "\n\n💰 <b>LLM Costs</b>\n  нет данных"

    agent_models = agent_models or {}
    total_usd = sum(r["cost_usd"] for r in cost_rows)
    total_rub = total_usd * USD_TO_RUB
    total_prompt = sum(r["prompt_tokens"] for r in cost_rows)
    total_completion = sum(r["completion_tokens"] for r in cost_rows)
    total_calls = sum(r["calls"] for r in cost_rows)

    lines = [f"\n\n💰 <b>LLM Costs</b> — ${total_usd:.6f} / {total_rub:.4f}₽ ({total_calls} calls)"]
    lines.append(f"  tokens: {total_prompt}→{total_completion}")
    for r in cost_rows:
        rub = r["cost_usd"] * USD_TO_RUB
        model = agent_models.get(r["agent"], "?")
        lines.append(
            f"  • {r['agent']} ×{r['calls']}: "
            f"${r['cost_usd']:.6f} / {rub:.4f}₽ "
            f"({r['prompt_tokens']}→{r['completion_tokens']}) "
            f"[{model}]"
        )
    return "\n".join(lines)


class TelegramReporter:
    def __init__(self):
        self.start_time = None
        self.start_utc = None
        self.results = []

    def add_result(self, nodeid, outcome, duration, error_msg=None):
        self.results.append({
            "nodeid": nodeid,
            "outcome": outcome,
            "duration": duration,
            "error_msg": error_msg,
        })

    def format_report(self, env, cost_rows=None, agent_models=None):
        passed = sum(1 for r in self.results if r["outcome"] == "passed")
        failed = sum(1 for r in self.results if r["outcome"] == "failed")
        total = len(self.results)
        elapsed = round(time.time() - self.start_time) if self.start_time else 0

        status_icon = "✅" if failed == 0 else "❌"
        status_text = "ALL PASSED" if failed == 0 else f"{failed} FAILED"
        header = (
            f"<b>ОТЧЕТ ЦОИФТ: INFATIUM</b>\n\n"
            f"🧪 <b>Regress {env.upper()} — {status_icon} {status_text}</b>\n"
            f"{passed}/{total} passed · {failed} failed · {elapsed}s\n"
        )

        groups = defaultdict(list)
        for r in self.results:
            parts = r["nodeid"].split("::", 1)
            filename = Path(parts[0]).stem if parts else "unknown"
            group = filename.replace("test_", "").replace("_", " ").title()
            groups[group].append(r)

        sections = []
        for group, tests in groups.items():
            g_passed = sum(1 for t in tests if t["outcome"] == "passed")
            g_failed = len(tests) - g_passed
            g_dur = sum(t["duration"] for t in tests)
            g_icon = "✅" if g_failed == 0 else "❌"
            lines = [f"\n{g_icon} <b>{group}</b> ({len(tests)} tests, {g_dur:.1f}s)"]
            for t in tests:
                test_name = t["nodeid"].split("::")[-1] if "::" in t["nodeid"] else t["nodeid"]
                icon = "✅" if t["outcome"] == "passed" else "❌"
                lines.append(f"  {icon} {test_name} ({t['duration']:.1f}s)")
                if t["error_msg"]:
                    err = t["error_msg"][:200].replace("<", "&lt;").replace(">", "&gt;")
                    lines.append(f"      <code>{err}</code>")
            sections.append("\n".join(lines))

        cost_section = _format_cost_section(cost_rows, agent_models)

        if failed == 0:
            footer = "\n\n✅ Рекомендовано ✅"
        else:
            footer = "\n\n❌ Не рекомендовано ❌"

        return header + "\n".join(sections) + cost_section + footer

    def send(self, env, cost_rows=None, agent_models=None):
        text = self.format_report(env, cost_rows, agent_models)
        chunks = self._split_message(text)
        for chunk in chunks:
            try:
                httpx.post(TG_URL, json={
                    "chat_id": CHAT_ID,
                    "message_thread_id": THREAD_ID,
                    "text": chunk,
                    "parse_mode": "HTML",
                }, timeout=10.0)
            except Exception as e:
                print(f"WARNING: Telegram send failed: {e}")

    @staticmethod
    def _split_message(text):
        if len(text) <= MAX_MSG_LEN:
            return [text]
        chunks = []
        current = ""
        for line in text.split("\n"):
            if len(current) + len(line) + 1 > MAX_MSG_LEN:
                if current:
                    chunks.append(current)
                current = line
            else:
                current = current + "\n" + line if current else line
        if current:
            chunks.append(current)
        return chunks


_reporter = None


def pytest_configure(config):
    global _reporter
    _reporter = TelegramReporter()
    config._tg_reporter = _reporter


def pytest_sessionstart(session):
    if _reporter:
        _reporter.start_time = time.time()
        _reporter.start_utc = datetime.now(timezone.utc)


def pytest_runtest_logreport(report):
    if _reporter is None:
        return
    if report.when == "call" or (report.when == "setup" and report.failed):
        error_msg = None
        if report.failed and report.longreprtext:
            error_msg = report.longreprtext.split("\n")[-1]
        _reporter.add_result(
            nodeid=report.nodeid,
            outcome=report.outcome,
            duration=report.duration,
            error_msg=error_msg,
        )


def pytest_sessionfinish(session, exitstatus):
    config = session.config
    if hasattr(config, "workerinput"):
        return
    if not hasattr(config, "_tg_reporter"):
        return
    if not config.getoption("tg_report", default=True):
        return
    reporter = config._tg_reporter
    if not reporter.results:
        return
    env = config.getoption("env", default="dev")
    namespace = "infatium-prod" if env == "prod" else "infatium-dev"
    try:
        cost_rows = _fetch_llm_costs(namespace, reporter.start_utc)
    except Exception:
        print(f"WARNING: Failed to fetch LLM costs:\n{traceback.format_exc()}")
        cost_rows = None
    try:
        agent_models = _fetch_agent_models(namespace)
    except Exception:
        print(f"WARNING: Failed to fetch agent models:\n{traceback.format_exc()}")
        agent_models = None
    try:
        reporter.send(env, cost_rows, agent_models)
    except Exception:
        print(f"WARNING: Telegram report failed:\n{traceback.format_exc()}")
