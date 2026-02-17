---
name: healthcheck
description: Check health of Infatium/Makefeed platform services. Use when user says "healthcheck", "health", "статус сервисов", "всё ли работает", "проверь здоровье", "check services".
argument-hint: [full|prod]
---

# Healthcheck - Platform Health Check

Quick or full health check of all Infatium/Makefeed services.

## Modes

| Command | Mode | What it checks |
|---------|------|----------------|
| `/healthcheck` | Quick (default, dev) | Pods + GlitchTip errors |
| `/healthcheck full` | Full (dev) | Pods + GlitchTip + Prometheus metrics + Loki error logs |
| `/healthcheck prod` | Quick (prod) | Same as quick but for production |
| `/healthcheck full prod` | Full (prod) | Full check on production |

## Configuration

| Param | Dev | Prod |
|-------|-----|------|
| Namespace | `infatium-dev` | `infatium-prod` |
| Kubeconfig | `~/.kube/nirssyan-infra.kubeconfig` | `~/.kube/nirssyan-infra.kubeconfig` |

## Services to Check

### Application Services (14)
```
app-api-python, app-api-go, app-auth-go, app-integrations-go,
app-integrations-python, app-landing-typescript,
worker-agents-python, worker-bot-python, worker-poller-go,
worker-processor-go, worker-processor-python, worker-rss-python,
worker-telegram-python, worker-web-python
```

### Infrastructure (2)
```
redis, nats
```

## Quick Mode — 2 Parallel Subagents

Launch **two Task agents in a single message** (parallel):

### Agent 1: Pod Status (haiku)

```
Prompt: "Run this bash command and return the output formatted as a markdown table:

KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get pods -n {NAMESPACE} -o wide --no-headers | \
python3 -c \"
import sys
print(f'{\"Pod\":<55} {\"Status\":<12} {\"Restarts\":<10} {\"Age\":<10} {\"Node\":<20}')
print('-' * 107)
for line in sys.stdin:
    parts = line.split()
    if len(parts) >= 7:
        pod = parts[0][:54]
        ready = parts[1]
        status = parts[2]
        restarts = parts[3]
        age = parts[4]
        node = parts[6] if len(parts) > 6 else '?'
        marker = '❌' if status != 'Running' else '⚠️' if int(restarts.split('(')[0]) > 0 else '✅'
        print(f'{marker} {pod:<53} {status:<12} {restarts:<10} {age:<10} {node:<20}')
\"
"
```

### Agent 2: GlitchTip Errors (haiku)

```
Prompt: "Run this bash command and return the output:

HTTPS_PROXY='' HTTP_PROXY='' curl -s \
  -H 'Authorization: Bearer '$GLITCHTIP_TOKEN'' \
  'https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/?limit=10' | \
python3 -c \"
import json, sys
data = json.load(sys.stdin)
if not data:
    print('✅ No recent errors in GlitchTip')
else:
    print(f'⚠️ {len(data)} recent error(s) in GlitchTip:')
    print()
    print(f'{chr(35):>4} {\"ID\":<8} {\"Count\":>6}  Title')
    print('-' * 70)
    for i, issue in enumerate(data, 1):
        iid = issue.get('id', '?')
        title = issue.get('title', 'Unknown')[:45]
        count = issue.get('count', 0)
        print(f'{i:>4} {iid:<8} {count:>6}  {title}')
\"
"
```

### Synthesize

After both agents return, combine into a single report:

```markdown
## Healthcheck — {namespace} ({mode})

### Pod Status
{Agent 1 output}

### GlitchTip Errors (recent)
{Agent 2 output}

**Overall: HEALTHY / DEGRADED / UNHEALTHY**
```

## Full Mode — 4 Parallel Subagents

Launch **four Task agents in a single message** (parallel):

### Agent 1: Pod Status (haiku)
Same as Quick Mode Agent 1.

### Agent 2: GlitchTip Errors (haiku)
Same as Quick Mode Agent 2.

### Agent 3: Prometheus Metrics (haiku)

```
Prompt: "Load the Grafana MCP tools by running ToolSearch for '+grafana query_prometheus'.
Then query these Prometheus metrics for namespace {NAMESPACE}:

1. Container CPU usage (last 5m):
   sum(rate(container_cpu_usage_seconds_total{namespace=\"{NAMESPACE}\"}[5m])) by (container)

2. Container memory usage:
   sum(container_memory_working_set_bytes{namespace=\"{NAMESPACE}\"}) by (container)

3. Pod restart count (last 1h):
   sum(increase(kube_pod_container_status_restarts_total{namespace=\"{NAMESPACE}\"}[1h])) by (container)

Format results as a table with columns: Container, CPU (cores), Memory (MB), Restarts (1h).
Flag any container using >500m CPU or >512MB memory."
```

### Agent 4: Recent Log Errors (haiku)

```
Prompt: "Load the Grafana MCP tools by running ToolSearch for '+grafana query_loki'.
Then query Loki for error logs in namespace {NAMESPACE} for the last 15 minutes:

LogQL: {namespace=\"{NAMESPACE}\"} |~ \"(?i)(error|panic|exception|fatal)\"
datasourceUid: P8E80F9AEF21F6940
maxLines: 50

Group errors by container and show count per container. List the 3 most recent error messages."
```

### Synthesize Full Report

```markdown
## Healthcheck — {namespace} (full)

### Pod Status
{Agent 1 output}

### GlitchTip Errors
{Agent 2 output}

### Resource Usage
{Agent 3 output}

### Recent Log Errors (15 min)
{Agent 4 output}

### Summary
| Service | Pods | Restarts | CPU | Memory | Errors |
|---------|------|----------|-----|--------|--------|
| ... | ... | ... | ... | ... | ... |

**Overall: HEALTHY / DEGRADED / UNHEALTHY**
```

## Health Classification

| Status | Criteria |
|--------|----------|
| HEALTHY | All pods Running, 0 restarts, no critical errors |
| DEGRADED | Some warnings: restarts > 0, non-critical errors, high resource usage |
| UNHEALTHY | Pods not Running, panics, OOMKilled, critical GlitchTip errors |
