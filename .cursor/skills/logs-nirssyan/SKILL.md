---
name: logs-nirssyan
description: Search Kubernetes logs via Grafana Loki using natural language queries. Use when user wants to find logs, debug errors, investigate issues, or search for patterns in any namespace of the infra-startup cluster (nirssyan project).
---

# Kubernetes Logs Search via Loki

Search logs across the infra-startup Kubernetes cluster using natural language queries.

## MANDATORY: Use Haiku Subagent

**Delegate the log search to a Haiku subagent using the Task tool.**

## CRITICAL RULES FOR SUBAGENT

1. **DO NOT use memory tools** (add_memory, search_memory) — just return results
2. **TRY MCP first** — use `mcp__grafana__query_loki_logs` if available
3. **FALLBACK to curl** — if MCP unavailable, use curl to Grafana API
4. **RETURN formatted log results**, nothing else

## Container Names

Actual container names in the cluster (use these in LogQL queries):

### infatium-dev / infatium-prod

| Container | Service | JSON Logs | Description |
|-----------|---------|-----------|-------------|
| `app-api-go` | go-api | Yes | REST API (chi router) |
| `app-auth-go` | go-auth | Yes | Auth service |
| `app-integrations-go` | go-integrations | Yes | Webhooks (AppStore, Sentry) |
| `app-registry-go` | go-registry | Yes | LLM model sync |
| `app-landing-typescript` | landing | No | Next.js landing |
| `worker-poller-go` | go-poller | Yes | RSS/Web/Telegram polling |
| `worker-processor-go` | go-processor | Yes | NATS consumers, post processing |
| `worker-agents-python` | agents | No | AI agents (LangChain) |
| `nats` | NATS | No | Message broker |
| `postgres` | PostgreSQL | No | Database |
| `redis` | Redis | No | Cache |

### scrapers-dev

| Container | Service | JSON Logs | Description |
|-----------|---------|-----------|-------------|
| `go-rss-api` | go-rss-api | Yes | RSS API |
| `go-scraper` | go-scraper | Yes | Web scraper |
| `crawl4ai` | crawl4ai | No | AI crawler |
| `postgres` | PostgreSQL | No | Database |

## JSON Logs (Go Services)

All Go services output structured JSON logs via zerolog. Use `| json` for field-based filtering:

### Available JSON Fields

| Field | Description | Example Values |
|-------|-------------|----------------|
| `level` | Log level | `info`, `error`, `warn`, `debug` |
| `service` | Service name | `go-api`, `go-processor` |
| `method` | HTTP method | `GET`, `POST`, `PUT`, `DELETE` |
| `path` | Request path | `/feeds/create`, `/chats` |
| `status` | HTTP status code | `200`, `400`, `500` |
| `duration` | Request duration | `0.123` (seconds) |
| `request_id` | Unique request ID | `abc123` |
| `event_id` | Event identifier | `evt_xxx` |
| `raw_feed_id` | Feed source ID | `uuid` |
| `message` | Log message | `Request processed` |

### JSON LogQL Examples

```logql
# Errors by level field
{namespace="infatium-dev", container="app-api-go"} | json | level="error"

# 500+ status codes
{namespace="infatium-dev", container="app-api-go"} | json | status >= 500

# Specific endpoint
{namespace="infatium-dev", container="app-api-go"} | json | path="/feeds/create"

# By request_id
{namespace="infatium-dev"} | json | request_id="abc123"

# By raw_feed_id
{namespace="infatium-dev"} | json | raw_feed_id="uuid-value"

# Slow requests (>1s)
{namespace="infatium-dev", container="app-api-go"} | json | duration > 1

# Combined filters
{namespace="infatium-dev", container="app-api-go"} | json | level="error" | method="POST"

# Processor logs
{namespace="infatium-dev", container="worker-processor-go"} | json | level="error"

# Poller logs
{namespace="infatium-dev", container="worker-poller-go"} | json | level="error"

# Scraper logs
{namespace="scrapers-dev", container="go-scraper"} | json | level="error"
```

## Subagent Invocation

```
Task(
    subagent_type="general-purpose",
    model="haiku",
    description="Search Loki logs",
    prompt="""Search Kubernetes logs via Grafana Loki.

User query: {USER_QUERY}

CRITICAL RULES:
- DO NOT use memory tools (add_memory, search_memory) — just return results
- RETURN formatted results directly
- For Go services, use `| json` for field filtering

## Container Name Mapping

Use these EXACT container names in LogQL queries:

infatium-dev / infatium-prod:
- "api", "backend", "go-api" → container="app-api-go"
- "auth" → container="app-auth-go"
- "integrations" → container="app-integrations-go"
- "registry" → container="app-registry-go"
- "poller", "telegram", "rss" → container="worker-poller-go"
- "processor" → container="worker-processor-go"
- "agents" → container="worker-agents-python"
- "landing" → container="app-landing-typescript"

scrapers-dev:
- "scraper" → container="go-scraper"
- "rss-api" → container="go-rss-api"
- "crawl" → container="crawl4ai"

## Method 1: MCP (preferred)

Try this first:
```python
# Simple text search
mcp__grafana__query_loki_logs(
    datasourceUid="P8E80F9AEF21F6940",
    logql='{namespace="infatium-dev", container="app-api-go"} |~ "error|Error"',
    limit=50,
    direction="backward"
)

# JSON field filtering (Go services)
mcp__grafana__query_loki_logs(
    datasourceUid="P8E80F9AEF21F6940",
    logql='{namespace="infatium-dev", container="app-api-go"} | json | level="error"',
    limit=50,
    direction="backward"
)

# Search by request_id
mcp__grafana__query_loki_logs(
    datasourceUid="P8E80F9AEF21F6940",
    logql='{namespace="infatium-dev"} | json | request_id="abc123"',
    limit=100,
    direction="backward"
)
```

## Method 2: Curl fallback (if MCP unavailable)

If MCP tools are not available, use curl:
```bash
curl -s -X POST "https://grafana.infra.makekod.ru/api/ds/query" \
  -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": {"uid": "P8E80F9AEF21F6940"},
      "expr": "{namespace=\"infatium-dev\", container=\"app-api-go\"} | json | level=\"error\"",
      "queryType": "range",
      "maxLines": 50
    }],
    "from": "now-30m",
    "to": "now"
  }' 2>/dev/null | jq -r '.results.A.frames[0].data.values[2][]?' 2>/dev/null | head -30
```

## Method 3: kubectl fallback

If both fail:
```bash
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl logs -n {namespace} deployment/{deployment-name} --tail=100 2>&1 | grep -iE "{pattern}"
```

Note: deployment names match container names (e.g., deployment/app-api-go).

## Query Parsing

1. **Namespace** (default: infatium-dev)
   - "prod", "production", "прод" → infatium-prod
   - "monitoring", "grafana", "loki", "n8n" → infrastructure
   - "scraper", "scrapers", "rss-api", "crawl" → scrapers-dev
   - Otherwise → infatium-dev

2. **Container** (if specified) — see Container Name Mapping above

3. **Pattern / Field Filters**
   - "errors", "ошибки" → `| json | level="error"` (for Go services)
   - "warnings" → `| json | level="warn"`
   - "500 errors" → `| json | status >= 500`
   - "request_id X" → `| json | request_id="X"`
   - "feed X" → `| json | raw_feed_id="X"`
   - Specific text → use `|= "text"` operator

## LogQL Examples

# JSON field filtering (Go services)
{namespace="infatium-dev", container="app-api-go"} | json | level="error"
{namespace="infatium-dev", container="app-api-go"} | json | status >= 400
{namespace="infatium-dev"} | json | request_id="abc123"
{namespace="infatium-dev", container="worker-processor-go"} | json | level="error"
{namespace="scrapers-dev", container="go-scraper"} | json | level="error"

# Text-based search (any service)
{namespace="infatium-dev", container="app-api-go"} |~ "error|Error|ERROR"
{namespace="infatium-dev"} |= "DigestScheduler"

# Exclude noise
{namespace="infatium-dev", container="app-api-go"} | json | level="error" != "healthcheck"

## Output Format

Return results as:
- Timestamp | Log message (or key JSON fields)
- Group related entries
- Summarize key findings

DO NOT write to memory. Just return the log results.
"""
)
```

## Configuration

| Parameter | Value |
|-----------|-------|
| Grafana URL | `https://grafana.infra.makekod.ru` |
| API Token | `$GRAFANA_API_TOKEN` |
| Datasource UID | `P8E80F9AEF21F6940` |
| Default namespace | `infatium-dev` |
| Kubeconfig | `~/.kube/nirssyan-infra.kubeconfig` |

## Available Namespaces

| Namespace | Purpose | Key Containers (JSON Logs) | Other Containers |
|-----------|---------|---------------------------|------------------|
| `infatium-dev` | Dev environment | app-api-go, app-auth-go, app-integrations-go, app-registry-go, worker-poller-go, worker-processor-go | worker-agents-python, app-landing-typescript, nats, postgres, redis |
| `infatium-prod` | Production | (same as dev) | (same as dev) |
| `scrapers-dev` | Scrapers | go-scraper, go-rss-api | crawl4ai, postgres |
| `infrastructure` | Observability | — | grafana, loki, tempo, grafana-agent, n8n, docker-registry |

## Trigger Keywords

- "prod", "production", "прод" → `infatium-prod`
- "scraper", "scrapers" → `scrapers-dev`
- "grafana", "loki", "n8n", "monitoring" → `infrastructure`
- "api", "backend" → container `app-api-go` (supports `| json`)
- "auth" → container `app-auth-go` (supports `| json`)
- "poller", "telegram" → container `worker-poller-go` (supports `| json`)
- "processor" → container `worker-processor-go` (supports `| json`)
- "integrations" → container `app-integrations-go` (supports `| json`)
- "registry" → container `app-registry-go` (supports `| json`)
- "agents" → container `worker-agents-python`
- "scraper" → container `go-scraper` in `scrapers-dev` (supports `| json`)
- "errors", "ошибки" → `| json | level="error"` (for Go services)
- "warnings" → `| json | level="warn"`
- "500", "server errors" → `| json | status >= 500`
- "request X" → `| json | request_id="X"`
- "feed X" → `| json | raw_feed_id="X"`
