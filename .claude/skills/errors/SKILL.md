---
name: errors
description: View and search GlitchTip errors for Makefeed API. Use when user says "errors", "ошибки", "глитчтип", "glitchtip", "error tracking", or wants to check production errors.
argument-hint: [details <ID>|search <query>|stats]
---

# Errors - GlitchTip Error Tracking

View and analyze errors from GlitchTip for Makefeed API.

## Commands

| Command | Action |
|---------|--------|
| `/errors` | Last 10 errors (list) |
| `/errors details <ID>` | Error details with stacktrace |
| `/errors search <query>` | Search errors by text |
| `/errors stats` | Top errors by count (last 24h) |

## Configuration

```
API_URL=https://glitchtip.infra.makekod.ru/api/0
TOKEN=$GLITCHTIP_TOKEN
ORG=makefeed
PROJECT=infatium
```

**IMPORTANT:** Always use `HTTPS_PROXY="" HTTP_PROXY=""` before curl.

## Workflows

### List Recent Errors (default)

```bash
HTTPS_PROXY="" HTTP_PROXY="" curl -s \
  -H "Authorization: Bearer $GLITCHTIP_TOKEN" \
  "https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/?limit=10" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data:
    print('No errors found')
    sys.exit(0)
print(f'{'ID':<8} {'Count':>6} {'Last Seen':>20}  Title')
print('-' * 80)
for issue in data[:10]:
    iid = issue.get('id', '?')
    title = issue.get('title', 'Unknown')[:50]
    count = issue.get('count', 0)
    last_seen = issue.get('lastSeen', '?')[:19].replace('T', ' ')
    print(f'{iid:<8} {count:>6} {last_seen:>20}  {title}')
"
```

### Error Details

Parse argument to get `<ID>`. Fetch issue details and latest events with stacktrace.

```bash
ERROR_ID="<ID>"

# Parallel: fetch issue details and events
HTTPS_PROXY="" HTTP_PROXY="" curl -s \
  -H "Authorization: Bearer $GLITCHTIP_TOKEN" \
  "https://glitchtip.infra.makekod.ru/api/0/issues/${ERROR_ID}/" > /tmp/glitchtip_issue.json &

HTTPS_PROXY="" HTTP_PROXY="" curl -s \
  -H "Authorization: Bearer $GLITCHTIP_TOKEN" \
  "https://glitchtip.infra.makekod.ru/api/0/issues/${ERROR_ID}/events/?limit=3" > /tmp/glitchtip_events.json &

wait

python3 << 'PYEOF'
import json

with open('/tmp/glitchtip_issue.json') as f:
    issue = json.load(f)

print(f"## Error #{issue.get('id', '?')}")
print(f"**Title:** {issue.get('title', 'Unknown')}")
print(f"**Count:** {issue.get('count', 0)}")
print(f"**First Seen:** {issue.get('firstSeen', '?')[:19].replace('T', ' ')}")
print(f"**Last Seen:** {issue.get('lastSeen', '?')[:19].replace('T', ' ')}")
print(f"**Level:** {issue.get('level', '?')}")
print(f"**Status:** {issue.get('status', '?')}")
print()

with open('/tmp/glitchtip_events.json') as f:
    events = json.load(f)

if events:
    latest = events[0]
    print("### Latest Event")
    print(f"**Timestamp:** {latest.get('dateCreated', '?')[:19].replace('T', ' ')}")

    entries = latest.get('entries', [])
    for entry in entries:
        if entry.get('type') == 'exception':
            for exc in entry.get('data', {}).get('values', []):
                print(f"\n**Exception:** {exc.get('type', '?')}: {exc.get('value', '?')}")
                frames = exc.get('stacktrace', {}).get('frames', [])
                if frames:
                    print("\n**Stacktrace (last 5 frames):**")
                    for frame in frames[-5:]:
                        filename = frame.get('filename', '?')
                        lineno = frame.get('lineNo', '?')
                        func = frame.get('function', '?')
                        print(f"  {filename}:{lineno} in {func}")
                        if frame.get('context'):
                            for ctx in frame['context']:
                                print(f"    {ctx}")
        elif entry.get('type') == 'message':
            print(f"\n**Message:** {entry.get('data', {}).get('formatted', '?')}")
PYEOF

rm -f /tmp/glitchtip_issue.json /tmp/glitchtip_events.json
```

### Search Errors

Parse argument to get `<query>`. Search issues by text.

```bash
QUERY="<query>"

HTTPS_PROXY="" HTTP_PROXY="" curl -s \
  -H "Authorization: Bearer $GLITCHTIP_TOKEN" \
  "https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/?query=${QUERY}&limit=10" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data:
    print('No errors matching query')
    sys.exit(0)
print(f'{'ID':<8} {'Count':>6} {'Last Seen':>20}  Title')
print('-' * 80)
for issue in data:
    iid = issue.get('id', '?')
    title = issue.get('title', 'Unknown')[:50]
    count = issue.get('count', 0)
    last_seen = issue.get('lastSeen', '?')[:19].replace('T', ' ')
    print(f'{iid:<8} {count:>6} {last_seen:>20}  {title}')
"
```

### Error Stats

Top errors sorted by count over last 24h.

```bash
HTTPS_PROXY="" HTTP_PROXY="" curl -s \
  -H "Authorization: Bearer $GLITCHTIP_TOKEN" \
  "https://glitchtip.infra.makekod.ru/api/0/projects/makefeed/infatium/issues/?sort=count&limit=15" | \
python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data:
    print('No errors found')
    sys.exit(0)
total_count = sum(i.get('count', 0) for i in data)
print(f'## Error Stats (top {len(data)} issues, total events: {total_count})')
print()
print(f'{'#':<4} {'ID':<8} {'Count':>6} {'Level':<8}  Title')
print('-' * 85)
for idx, issue in enumerate(data, 1):
    iid = issue.get('id', '?')
    title = issue.get('title', 'Unknown')[:45]
    count = issue.get('count', 0)
    level = issue.get('level', '?')
    print(f'{idx:<4} {iid:<8} {count:>6} {level:<8}  {title}')
"
```

## Output Format

Always present errors as a formatted table. For details, include stacktrace with file paths and line numbers.
