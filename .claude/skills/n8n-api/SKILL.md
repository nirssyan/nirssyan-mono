---
name: n8n-api
description: Work with n8n workflows via REST API (curl). Use when user says "n8n", "workflow", "execution", "посмотри n8n", "запусти workflow", or needs to inspect/modify n8n workflows. Fallback when MCP is unavailable.
---

# n8n REST API Skill

## Environment

Credentials in `~/.claude/.env`:
- `N8N_BASE_URL` — base URL (e.g. `https://n8n.dev.tms.natcar.ru`)
- `N8N_API_KEY` — API key

Helper script: `scripts/n8n_request.sh <METHOD> <PATH> [BODY]`

## Core Rule: ALL API calls via subagent

**Never call n8n API in the main context.** Always delegate to:

```
Task(subagent_type: "general-purpose", model: "haiku", prompt: "...")
```

This keeps n8n JSON responses out of the main conversation window.

## API Operations

| Operation | Method | Path |
|-----------|--------|------|
| List workflows | GET | `/api/v1/workflows` |
| Get workflow | GET | `/api/v1/workflows/:id` |
| Update workflow | PATCH | `/api/v1/workflows/:id` |
| Activate workflow | POST | `/api/v1/workflows/:id/activate` |
| Deactivate workflow | POST | `/api/v1/workflows/:id/deactivate` |
| List executions | GET | `/api/v1/executions?workflowId=X` |
| Get execution + data | GET | `/api/v1/executions/:id?includeData=true` |

## Subagent Prompt Templates

### Get workflow structure (nodes + connections)

```
Source ~/.claude/.env and run:
scripts/n8n_request.sh GET /api/v1/workflows/<ID>

From the response, extract and return ONLY:
1. Workflow name
2. List of nodes: name, type, position
3. Connections between nodes (source → target)
4. Whether workflow is active

Do NOT return the full JSON.
```

### Get execution data for a specific node

```
Source ~/.claude/.env and run:
scripts/n8n_request.sh GET "/api/v1/executions/<EXEC_ID>?includeData=true"

From the response, extract and return ONLY:
1. Execution status (success/error/waiting)
2. Start and end time
3. Data for node "<NODE_NAME>": input items and output items (first 3 items max)
4. If error — the error message

Do NOT return the full JSON.
```

### Update a Code node in workflow

This uses the Read → Modify → Patch pattern:

```
Step 1: Source ~/.claude/.env and run:
scripts/n8n_request.sh GET /api/v1/workflows/<ID>

Step 2: In the response, find the node named "<NODE_NAME>".
Replace its parameters.jsCode value with the new code below:

<NEW_CODE>

Step 3: Build a PATCH body with the full nodes array (all nodes, with the modified one) and connections.
Run:
scripts/n8n_request.sh PATCH /api/v1/workflows/<ID> '<PATCH_BODY>'

Return: confirmation with the updated node's code snippet (first 5 lines).
```

### List recent executions

```
Source ~/.claude/.env and run:
scripts/n8n_request.sh GET "/api/v1/executions?workflowId=<ID>&limit=5"

Return a table:
| ID | Status | Started | Finished | Duration |
```

## Usage Example

User: "Покажи структуру workflow Oa9FW7qOHIi7O8eh"

→ Spawn haiku subagent with "Get workflow structure" template, ID = Oa9FW7qOHIi7O8eh
→ Present summarized result to user
