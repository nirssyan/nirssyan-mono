---
name: incident
description: Investigate production incidents with parallel data gathering. Use when user says "incident", "инцидент", "что сломалось", "расследуй ошибку", "investigate error", or when triaging alerts.
argument-hint: ["error message"|GlitchTip Alert #ID]
---

# Incident - Production Incident Investigation

Parallel investigation of production incidents across GlitchTip, Loki logs, Prometheus metrics, and codebase.

## Commands

| Command | Action |
|---------|--------|
| `/incident` | Investigate current state (all services) |
| `/incident "error message"` | Investigate specific error |
| `/incident GlitchTip Alert #272` | Investigate specific GlitchTip alert |

## Configuration

| Param | Value |
|-------|-------|
| Default Namespace | `infatium-dev` |
| Kubeconfig | `~/.kube/nirssyan-infra.kubeconfig` |
| GlitchTip Token | `$GLITCHTIP_TOKEN` |
| Grafana Loki UID | `P8E80F9AEF21F6940` |

## Workflow — 3 Phases

### Phase 1: GATHER (Parallel Subagents)

Launch **3-4 Task agents in a single message** depending on whether error message is provided.

#### Agent 1: "observer" (haiku) — GlitchTip Errors

```
Prompt: "Investigate GlitchTip errors for the last 30 minutes.

Run this bash command:
HTTPS_PROXY='' HTTP_PROXY='' curl -s \
  -H 'Authorization: Bearer '$GLITCHTIP_TOKEN'' \
  'https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/?limit=15' | \
python3 -c \"
import json, sys
data = json.load(sys.stdin)
for issue in data:
    iid = issue.get('id', '?')
    title = issue.get('title', 'Unknown')
    count = issue.get('count', 0)
    level = issue.get('level', '?')
    last_seen = issue.get('lastSeen', '?')[:19]
    print(f'#{iid} [{level}] ({count}x) {title}')
    print(f'  Last seen: {last_seen}')
\"

{IF_SPECIFIC_ERROR: Also search for the specific error:
HTTPS_PROXY='' HTTP_PROXY='' curl -s \
  -H 'Authorization: Bearer '$GLITCHTIP_TOKEN'' \
  'https://glitchtip.infra.makekod.ru/api/0/issues/{ERROR_ID}/events/?limit=3'
and show stacktraces from the events.}

Return: list of errors with IDs, counts, levels, timestamps, and stacktraces if available."
```

#### Agent 2: "log-analyzer" (haiku) — Loki Error Logs

```
Prompt: "Load Grafana MCP tools: run ToolSearch for '+grafana query_loki'.

Query Loki for error logs across all services in namespace {NAMESPACE} for the last 30 minutes:

LogQL: {namespace=\"{NAMESPACE}\"} |~ \"(?i)(error|panic|exception|fatal|traceback)\"
datasourceUid: P8E80F9AEF21F6940
maxLines: 100

{IF_SPECIFIC_ERROR: Also search for the specific error text:
LogQL: {namespace=\"{NAMESPACE}\"} |~ \"ESCAPED_ERROR_TEXT\"
}

Also run mcp__grafana__find_error_pattern_logs to identify recurring patterns.

Group results by container. For each container with errors:
- Count of error lines
- Most recent 2-3 error messages
- Timestamp of first and last error

Return structured summary of error patterns, affected services, and timeline."
```

#### Agent 3: "metrics-checker" (haiku) — Prometheus + K8s Events

```
Prompt: "Check system health via metrics and Kubernetes events.

1. Run these bash commands:

# Pod status and restarts
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get pods -n {NAMESPACE} --no-headers | \
  awk '{print $1, $2, $3, $4}'

# Recent K8s events (warnings/errors)
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get events -n {NAMESPACE} \
  --sort-by='.lastTimestamp' --field-selector type!=Normal 2>/dev/null | tail -15

# Check for OOMKilled
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get pods -n {NAMESPACE} -o json | \
python3 -c \"
import json, sys
data = json.load(sys.stdin)
for pod in data.get('items', []):
    name = pod['metadata']['name']
    for cs in pod.get('status', {}).get('containerStatuses', []):
        last = cs.get('lastState', {})
        if 'terminated' in last:
            reason = last['terminated'].get('reason', '?')
            if reason in ('OOMKilled', 'Error'):
                print(f'⚠️ {name}: {reason}')
\"

2. Load Grafana MCP tools: run ToolSearch for '+grafana query_prometheus'.
Then query:
- Error rate: sum(rate(http_requests_total{namespace=\"{NAMESPACE}\",status=~\"5..\"}[5m])) by (container)
- CPU spikes: sum(rate(container_cpu_usage_seconds_total{namespace=\"{NAMESPACE}\"}[5m])) by (container)

Return: pod statuses, K8s events, OOMKilled pods, error rates, CPU anomalies."
```

#### Agent 4: "code-investigator" (sonnet) — ONLY if error message provided

```
Prompt: "Investigate the following error in the codebase: '{ERROR_MESSAGE}'

1. Search for the error message text in the codebase:
   - Search in makefeed_n8n_claude/src/ for Python services
   - Search in infatium-bot/src/ for bot errors

2. Find the function/handler where this error originates

3. Check recent git changes near the error location:
   git log --oneline -5 -- <affected_file>
   git diff HEAD~3 -- <affected_file>

4. Identify potential root cause based on:
   - What the code does around the error
   - Any recent changes that could have introduced the issue

Return: affected file(s), function name, likely root cause, recent changes."
```

### Phase 2: CORRELATE (inline, after all agents return)

After all subagents return their data, cross-reference:

1. **Timeline**: Order all events by timestamp (GlitchTip errors, log entries, K8s events)
2. **Service mapping**: Which services appear across multiple data sources?
3. **Cascading failures**: Did an error in service A cause errors in service B?
4. **Root cause**: What was the first anomaly? What triggered the cascade?

### Phase 3: REPORT

Generate the final incident report:

```markdown
## Incident Report

**Time:** {first_error_time} → {latest_error_time}
**Affected Services:** {list of services}
**Impact:** {HIGH / MEDIUM / LOW}
**Namespace:** {namespace}

### Timeline
- HH:MM — {first event description}
- HH:MM — {subsequent events}
- HH:MM — {latest event}

### Root Cause (probable)
{description based on correlation of all data sources}

### Errors (GlitchTip)
| ID | Title | Count | Level | Last Seen |
|----|-------|-------|-------|-----------|
| ... | ... | ... | ... | ... |

### Log Errors by Service
| Service | Error Count | Sample Error |
|---------|-------------|--------------|
| ... | ... | ... |

### Infrastructure
| Check | Status | Details |
|-------|--------|---------|
| Pod Health | ✅/❌ | ... |
| OOMKilled | ✅/❌ | ... |
| K8s Events | ✅/❌ | ... |
| CPU/Memory | ✅/❌ | ... |

### Code Analysis (if applicable)
- **File:** {path}
- **Function:** {name}
- **Recent changes:** {summary}

### Recommendations
1. {immediate action — what to do right now}
2. {follow-up — what to investigate/fix later}
3. {prevention — how to prevent recurrence}
```

## Impact Classification

| Impact | Criteria |
|--------|----------|
| HIGH | User-facing service down, data loss, 500 errors on main endpoints |
| MEDIUM | Degraded performance, some features broken, non-critical errors |
| LOW | Internal service issues, non-user-facing, cosmetic errors |
