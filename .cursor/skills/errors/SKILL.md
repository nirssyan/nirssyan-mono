---
name: errors
description: Search and analyze errors from GlitchTip (self-hosted Sentry). Use when user wants to find errors, debug exceptions, investigate issues, or analyze error patterns in makefeed projects.
---

# GlitchTip Error Tracking

Search and analyze errors from the self-hosted GlitchTip instance.

## MANDATORY: Use Haiku Subagent

**Delegate the error search to a Haiku subagent using the Task tool.**

## CRITICAL RULES FOR SUBAGENT

1. **DO NOT use memory tools** (add_memory, search_memory) — just return results
2. **Use curl to GlitchTip API** — no MCP available for GlitchTip
3. **RETURN formatted error results**, nothing else
4. **ALWAYS disable proxy** — use `--noproxy '*'` flag in curl

## Subagent Invocation

```
Task(
    subagent_type="general-purpose",
    model="haiku",
    description="Search GlitchTip errors",
    prompt="""Search errors in GlitchTip.

User query: {USER_QUERY}

CRITICAL RULES:
- DO NOT use memory tools (add_memory, search_memory) — just return results
- ALWAYS use --noproxy '*' flag in curl commands
- RETURN formatted results directly

## API Configuration

- Base URL: https://glitchtip.infra.makekod.ru
- Token: 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415
- Organization: makefeed
- Project: infatium

## API Endpoints

### List all issues (errors)
```bash
curl -s --noproxy '*' \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  "https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/" | jq .
```

### Get issue details
```bash
curl -s --noproxy '*' \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  "https://glitchtip.infra.makekod.ru/api/0/issues/{ISSUE_ID}/" | jq .
```

### Get issue events (occurrences)
```bash
curl -s --noproxy '*' \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  "https://glitchtip.infra.makekod.ru/api/0/issues/{ISSUE_ID}/events/" | jq .
```

### List organizations
```bash
curl -s --noproxy '*' \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  "https://glitchtip.infra.makekod.ru/api/0/organizations/" | jq .
```

### List projects
```bash
curl -s --noproxy '*' \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  "https://glitchtip.infra.makekod.ru/api/0/organizations/makefeed/projects/" | jq .
```

### Update issue status (resolve/ignore)
```bash
curl -s --noproxy '*' -X PUT \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  -H "Content-Type: application/json" \
  -d '{"status": "resolved"}' \
  "https://glitchtip.infra.makekod.ru/api/0/organizations/makefeed/issues/?id={ISSUE_ID}"
```

**Available statuses:**
- `resolved` — Issue is fixed
- `ignored` — Issue is acknowledged but won't be fixed
- `unresolved` — Reopen a resolved/ignored issue

**Bulk update multiple issues:**
```bash
curl -s --noproxy '*' -X PUT \
  -H "Authorization: Bearer 8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415" \
  -H "Content-Type: application/json" \
  -d '{"status": "resolved"}' \
  "https://glitchtip.infra.makekod.ru/api/0/organizations/makefeed/issues/?id=5&id=6&id=7"
```

## Query Parsing

1. **Default behavior**: List all unresolved issues
2. **"details ID"** or **"issue ID"** → Get specific issue details
3. **"events ID"** → Get all events for issue
4. **"resolve ID"** or **"зарезолвить ID"** → Mark issue as resolved
5. **"ignore ID"** → Mark issue as ignored
6. **Search keywords** → Filter by title/metadata

## Output Format

For issue list, show:
| ID | Count | Title | First Seen | Last Seen |

For issue details, show:
- Full error message
- Stack trace (if available)
- Metadata (filename, function)
- Event count

## Response Parsing

Issues contain:
- id: Issue ID
- count: Number of occurrences
- title: Error title/message
- metadata: {type, value, filename, function}
- firstSeen, lastSeen: Timestamps
- status: unresolved/resolved/ignored

DO NOT write to memory. Just return the error results.
"""
)
```

## Configuration

| Parameter | Value |
|-----------|-------|
| GlitchTip URL | `https://glitchtip.infra.makekod.ru` |
| API Token | `8dd6aaa8d9290ab3fbeb879bf4f2a77b91b5dc43913871d59ec150cafbe4b415` |
| Organization | `makefeed` |
| Project | `infatium` |
| DSN | `https://f3a86334caf4467da51f2f4d60ae7186@glitchtip.infra.makekod.ru/1` |

## API Reference

### Issue Fields

| Field | Description |
|-------|-------------|
| `id` | Unique issue ID |
| `count` | Number of occurrences |
| `title` | Error title/message |
| `type` | `error` or `default` |
| `level` | `error`, `warning`, `info` |
| `status` | `unresolved`, `resolved`, `ignored` |
| `metadata.type` | Exception type (e.g., `HTTPException`) |
| `metadata.value` | Exception message |
| `metadata.filename` | Source file |
| `metadata.function` | Function name |
| `firstSeen` | First occurrence timestamp |
| `lastSeen` | Last occurrence timestamp |
| `userCount` | Affected users count |

### Query Parameters

| Parameter | Description |
|-----------|-------------|
| `query` | Search string |
| `status` | Filter by status |
| `cursor` | Pagination cursor |

## Trigger Keywords

- "errors", "ошибки", "exceptions" → List all issues
- "issue N", "ошибка N" → Get issue details by ID
- "events N" → Get events for issue ID
- "resolved", "решённые" → Filter resolved issues
- "unresolved", "активные" → Filter unresolved issues
- "resolve N", "зарезолвить N" → Mark issue N as resolved
- "ignore N", "игнорировать N" → Mark issue N as ignored
- "reopen N" → Reopen resolved/ignored issue

## Web UI

GlitchTip web interface: https://glitchtip.infra.makekod.ru

Login credentials:
- Email: admin@makekod.ru
- Password: GlitchTip123!
