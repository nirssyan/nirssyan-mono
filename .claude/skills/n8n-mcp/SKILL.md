---
name: n8n-mcp
description: Use when creating, updating, or managing n8n workflows via MCP - provides structured workflow for discovery, validation, creation, and testing with correct tool usage patterns and AI connection handling
---

# Working with n8n MCP

## Overview

Use n8n MCP tools for ALL workflow operations. Never create JSON manually.

**Core principle:** Validate before create, prefer partial updates, AI connections flow TO consumer.

## Context-Efficient Reading (CRITICAL)

**Use n8n-summary-mcp for reading, n8n-mcp for modifications!**

### Reading Pattern (n8n-summary-mcp)
1. `n8n_workflow_summary({workflowId})` → ASCII diagram + node list (~1K tokens)
2. `n8n_get_node({workflowId, nodeName})` → single node config (~500 tokens)
3. `n8n_search_workflow({workflowId, query})` → find code/variables

### Token Comparison
| Tool | Tokens (~37 nodes) | Use Case |
|------|-------------------|----------|
| `n8n_workflow_summary` | ~1K | Understand structure, list all nodes |
| `n8n_get_node` | ~500 | Read single node config |
| `n8n_search_workflow` | ~200-1K | Find where code/variable is used |
| `n8n_get_workflow({mode: "structure"})` | ~2-3K | Need connections info |
| `n8n_get_workflow({mode: "full"})` | ~8-15K | Need workflow settings |

### Example: Finding and Reading a Node
```javascript
// ✅ BEST - use n8n-summary-mcp
n8n_workflow_summary({workflowId: "..."})  // See all nodes
n8n_get_node({workflowId: "...", nodeName: "Order Proposal Agent"})  // Get config

// ✅ GOOD - if need connections
n8n_get_workflow({id: "...", mode: "structure"})

// ❌ BAD - wastes tokens
n8n_get_workflow({id: "...", mode: "full"})
```

## Subagent Pattern for Large Workflows (MANDATORY)

**CRITICAL: You MUST use subagents for these operations. Do NOT read large agents directly!**

### Automatic Triggers - USE SUBAGENT WHEN:

1. **User asks about agents/prompts** → "покажи агентов", "что делает агент X", "какие сценарии"
2. **Need to read AI Agent systemMessage** → These are 2-5K tokens each!
3. **Planning changes to agents** → Need to understand structure first
4. **Comparing multiple agents** → Would be 10-20K tokens directly
5. **Full workflow audit** → "проверь workflow", "что там есть"

### DO NOT use subagent for:
- Simple structure query → use `n8n_workflow_summary`
- Quick search → use `n8n_search_workflow`
- Reading non-agent nodes → use `n8n_get_node`

### How to Use

**Always use `general-purpose` with `model: haiku`:**

```javascript
Task({
  subagent_type: "general-purpose",
  model: "haiku",  // REQUIRED - fast and cheap
  description: "<short description>",
  prompt: `<instructions with workflow ID and task>`
})
```

**Why haiku?** Fast, cheap, sufficient for read-only analysis. MCP tools are inherited automatically.

### Usage Examples

**Analyze single large agent:**
```javascript
Task({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Analyze Order Agent",
  prompt: `You are an n8n workflow analyst. Return CONCISE JSON summaries.

Use mcp__n8n-summary-mcp__n8n_get_node to get:
- Workflow: aSUAGHHW2ZdojljS
- Node: "Order Proposal Pending Agent"

Return JSON:
{
  "agent": {
    "name": "...",
    "purpose": "1 sentence",
    "scenarios": ["scenario IDs"],
    "input_vars": ["variables from input"],
    "key_logic": "decision points"
  }
}

NEVER return full systemMessage - summarize logic. Keep under 500 tokens.`
})
```

**Compare agents:**
```javascript
Task({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Compare workflow agents",
  prompt: `You are an n8n workflow analyst.

1. Use mcp__n8n-summary-mcp__n8n_workflow_summary for workflow aSUAGHHW2ZdojljS
2. Identify all AI Agent nodes
3. Use mcp__n8n-summary-mcp__n8n_get_node for each agent

Return JSON:
{
  "summary": "overview",
  "agents": [{name, purpose, scenarios}],
  "common_patterns": [...],
  "differences": [...]
}

NEVER return full systemMessage. Keep under 800 tokens.`
})
```

**Full audit:**
```javascript
Task({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Audit workflow",
  prompt: `You are an n8n workflow analyst.

Workflow: aSUAGHHW2ZdojljS

1. Get structure with mcp__n8n-summary-mcp__n8n_workflow_summary
2. Analyze data flow and agent roles

Return JSON:
{
  "summary": "workflow overview",
  "agents": [{name, role}],
  "data_flow": "how data moves",
  "potential_issues": [...]
}

Keep under 1000 tokens.`
})
```

### Token Savings

| Operation | Direct Call | With Subagent |
|-----------|-------------|---------------|
| Read 1 large agent | ~3-5K tokens | ~500 tokens |
| Compare 3 agents | ~10-15K tokens | ~800 tokens |
| Full workflow audit | ~15-20K tokens | ~1K tokens |

### Pattern: Reader + Planner (Read → Plan → Execute)

When you need to understand WHERE to make a change before making it:

```javascript
Task({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Plan agent change",
  prompt: `Workflow: aSUAGHHW2ZdojljS

TASK: <describe the change needed>

1. Read agent with mcp__n8n-summary-mcp__n8n_get_node({workflowId, nodeName: "Agent Name"})
2. Analyze systemMessage structure
3. Find WHERE to add/modify

Return JSON:
{
  "current_structure": {
    "sections": ["main sections in prompt"],
    "scenarios": ["handled scenarios"],
    "actions": ["available actions"]
  },
  "change_plan": {
    "location": "After which section/block",
    "what_to_change": "Description",
    "related_sections": ["may need updates"]
  },
  "snippet": "Small code snippet showing insertion point with context"
}

Return SPECIFIC locations, not full prompt. Keep under 600 tokens.`
})
```

**Use when:**
- Adding new scenario handling
- Modifying decision logic
- Need to understand prompt structure first

### Pattern: Batch Executor (Mass Updates)

When updating multiple agents with same change:

```javascript
Task({
  subagent_type: "general-purpose",
  model: "sonnet",  // sonnet for complex write operations
  description: "Batch update agents",
  prompt: `Workflow: aSUAGHHW2ZdojljS

TASK: <describe change to apply to all agents>

For EACH agent node:
1. Read config: mcp__n8n-summary-mcp__n8n_get_node
2. Modify systemMessage as needed
3. Update with mcp__n8n-mcp__n8n_update_partial_workflow

CRITICAL - Agent node updates MUST include ALL parameters:
{
  "type": "updateNode",
  "nodeName": "Agent Name",
  "updates": {
    "parameters": {
      "promptType": "define",
      "text": "={{ JSON.stringify($json) }}",
      "options": { "systemMessage": "=<FULL UPDATED PROMPT>" }
    }
  }
}

After ALL updates, validate: mcp__n8n-mcp__n8n_validate_workflow({id: "..."})

Return JSON:
{
  "updated": ["Agent 1", "Agent 2"],
  "skipped": ["Agent 3 - reason"],
  "validation": "pass/fail + issues"
}`
})
```

**Use when:**
- Adding same logic to multiple agents (logging, error handling)
- Renaming variables across all agents
- Migrating prompt structure

### Workflow: Read → Plan → Execute

```
Step 1: Reader+Planner subagent
        ↓
        Returns: structure + change plan + snippet
        ↓
Step 2: You review plan, adjust if needed
        ↓
Step 3: Execute via Batch Executor OR direct n8n_update_partial_workflow
```

## Consult Specialized Skills (n8n-mcp-skills)

**IMPORTANT:** For specific n8n topics, ALWAYS consult the appropriate specialized skill from `n8n-mcp-skills@n8n-mcp-skills` plugin:

| Topic | Skill Name | When to Use |
|-------|------------|-------------|
| **Expression syntax** | `n8n-mcp-skills:n8n-expression-syntax` | Writing `{{ }}` expressions, using $json, $node, $env |
| **MCP tools** | `n8n-mcp-skills:n8n-mcp-tools-expert` | Using n8n-mcp tools effectively, tool selection |
| **Workflow patterns** | `n8n-mcp-skills:n8n-workflow-patterns` | Architecture, webhook processing, AI workflows |
| **Validation errors** | `n8n-mcp-skills:n8n-validation-expert` | Interpreting errors, false positives, auto-fixes |
| **Node configuration** | `n8n-mcp-skills:n8n-node-configuration` | Setting up nodes, property dependencies, AI connections |
| **JavaScript code** | `n8n-mcp-skills:n8n-code-javascript` | Writing Code nodes, $input patterns, return format |
| **Python code** | `n8n-mcp-skills:n8n-code-python` | Python Code nodes (use JS for 95% of cases!) |

**How to consult:**
```
Use the Skill tool: Skill("n8n-mcp-skills:n8n-expression-syntax")
```

**When to consult:**
- Writing expressions → `n8n-expression-syntax`
- Validation errors → `n8n-validation-expert`
- Creating new workflow → `n8n-workflow-patterns`
- Configuring complex nodes → `n8n-node-configuration`
- Writing Code node → `n8n-code-javascript`

## The Iron Law

```
NO WORKFLOW OPERATIONS WITHOUT n8n MCP TOOLS
```

Creating JSON files manually? STOP. Use `n8n_create_workflow`.
Using full update for small changes? STOP. Use `n8n_update_partial_workflow`.

**n8n-summary-mcp Tools (for reading):**
- `mcp__n8n-summary-mcp__n8n_workflow_summary` - ASCII diagram + node list
- `mcp__n8n-summary-mcp__n8n_get_node` - single node config
- `mcp__n8n-summary-mcp__n8n_search_workflow` - search inside nodes

**n8n-mcp Tools (for modifications):**
- `mcp__n8n-mcp__search_nodes` - find node types
- `mcp__n8n-mcp__get_node` - get node schema
- `mcp__n8n-mcp__n8n_create_workflow`
- `mcp__n8n-mcp__n8n_update_partial_workflow`
- `mcp__n8n-mcp__n8n_autofix_workflow`

## Four Phases

### Phase 1: Discovery (Context-Efficient)

**For existing workflows (use n8n-summary-mcp):**
```javascript
// Step 1: Get workflow overview
n8n_workflow_summary({workflowId: "..."})  // ~1K tokens

// Step 2: Get specific node config
n8n_get_node({workflowId: "...", nodeName: "Target Node"})  // ~500 tokens

// Step 3: Find where variable is used
n8n_search_workflow({workflowId: "...", query: "scenario"})
```

**For new node types (use n8n-mcp):**
```javascript
search_nodes({query: "webhook", limit: 5})
get_node({nodeType: "nodes-base.webhook", detail: "standard"})
```

**ALWAYS use `detail: "standard"`** - it covers 95% of cases (~1-2K tokens vs 3-8K for full).

### Phase 2: Validation

```
validate_node({nodeType: "...", config: {...}, profile: "runtime"})
validate_workflow({workflow: {...}})
```

Validate BEFORE creating. Not after.

### Phase 3: Creation/Update

**For new workflows:**
```
n8n_create_workflow({name: "...", nodes: [...], connections: {...}})
```

**For changes - ALWAYS use partial update:**
```
n8n_update_partial_workflow({
  id: "...",
  operations: [
    {type: "updateNode", nodeName: "HTTP", updates: {continueOnFail: true}}
  ]
})
```

Use `validateOnly: true` for preview before applying.

### Phase 4: Verification

```
n8n_autofix_workflow({id: "...", applyFixes: false})  // Preview first!
n8n_autofix_workflow({id: "...", applyFixes: true})   // Then apply
```

## AI Workflow Pattern

**CRITICAL:** AI connections flow TO consumer (reverse of normal):

```
[Language Model] --ai_languageModel--> [AI Agent]
[HTTP Tool]      --ai_tool-----------> [AI Agent]
[Memory]         --ai_memory---------> [AI Agent]
```

**Connection order:**
1. Create Language Model node FIRST
2. Create AI Agent node
3. Connect with `sourceOutput: "ai_languageModel"`
4. Add tools with `sourceOutput: "ai_tool"`

**8 AI connection types:** `ai_languageModel`, `ai_tool`, `ai_memory`, `ai_outputParser`, `ai_embedding`, `ai_vectorStore`, `ai_document`, `ai_textSplitter`

## Quick Reference

| Task | Tool | Key Parameters |
|------|------|----------------|
| **READING (n8n-summary-mcp)** | | |
| Workflow overview | `n8n_workflow_summary` | `workflowId` |
| Single node config | `n8n_get_node` | `workflowId`, `nodeName` |
| Search inside nodes | `n8n_search_workflow` | `workflowId`, `query` |
| **DISCOVERY (n8n-mcp)** | | |
| Find node types | `search_nodes` | `query`, `mode: "OR"` |
| Get node schema | `get_node` | `detail: "standard"` |
| **MODIFICATIONS (n8n-mcp)** | | |
| Validate node | `validate_node` | `profile: "runtime"` |
| Create workflow | `n8n_create_workflow` | `name`, `nodes[]`, `connections{}` |
| Update workflow | `n8n_update_partial_workflow` | `operations[]`, `validateOnly` |
| Fix issues | `n8n_autofix_workflow` | `applyFixes: false` first! |

## AI Agent Node Updates - CRITICAL

**DANGER ZONE:** When updating Agent nodes with `updateNode`, you MUST preserve `systemMessage`:

```javascript
// WRONG - will DELETE systemMessage:
{type: "updateNode", nodeId: "...", updates: {"parameters.options.maxTokens": 1000}}

// CORRECT - preserves systemMessage:
{type: "updateNode", nodeId: "...", updates: {
  "parameters.options.systemMessage": "=<FULL EXISTING PROMPT>",  // REQUIRED!
  "parameters.options.maxTokens": 1000
}}
```

**Before ANY Agent node update:**
1. Get node config: `n8n_get_node({workflowId: "...", nodeName: "Agent Name"})`
2. Copy `node.parameters.options.systemMessage`
3. Include the full systemMessage in your `updates` object
4. After update, verify systemMessage wasn't lost

**Recovery if systemMessage lost:**
```
n8n_workflow_versions({mode: "list", workflowId: "..."})
n8n_workflow_versions({mode: "get", workflowId: "...", versionId: <earlier_version>})
```

## Red Flags - STOP

- **Using `n8n_get_workflow` when `n8n_workflow_summary` or `n8n_get_node` would suffice!**
- **Using `mode: "full"` as first read operation (use n8n-summary-mcp first!)**
- Creating JSON files instead of using MCP tools
- Using `n8n_update_full_workflow` for small changes
- Using `detail: "full"` without trying `standard` first
- Skipping validation before create
- Applying autofix without preview
- Using `main` connections for AI nodes
- Saying "MCP tools not available" without checking `mcp__n8n-mcp__*`
- Writing workflow JSON to disk instead of calling API
- **Updating Agent node without including full systemMessage in updates**
- **Using `?.` optional chaining in n8n expressions** - NOT SUPPORTED!
- **Having `}}` in toolDescription or other text fields** - causes bracket errors
- **Using numeric sourceOutput/targetInput** - must be strings
- **Multiple connections to same Merge input index** - check input indices
- **Using `sourceNodeName` in addConnection** - use `source`/`target` instead
- **Using `mode: "combineByPosition"` directly** - must be `mode: "combine"` + `combineBy: "combineByPosition"`
- **Trying to fix Merge node connections via API** - fix in UI instead, API creates malformed `type: "1"` connections

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I need to see the whole workflow first" | Use `n8n_workflow_summary` - it shows structure + node list in ~1K tokens |
| "I need to read one node config" | Use `n8n_get_node` - returns just that node in ~500 tokens |
| "I'll just create JSON manually" | MCP tools handle validation, sanitization, and proper structure |
| "Full update is simpler" | Partial update is surgical, safer, and shows intent |
| "I need full detail for node config" | Standard covers 95% of cases. Try it first. |
| "Validation takes too long" | Validation catches errors before they hit production |
| "I know the connections work" | AI connections have specific direction requirements |
| "MCP server not configured" | Tools are available as `mcp__n8n-mcp__*`. Check your tool list. |
| "I can't find the MCP tools" | Look for `mcp__n8n-mcp__` prefix. They exist. |
| "Optional chaining is standard JS" | n8n uses custom expression parser, `?.` not supported |
| "The JSON example is just text" | n8n parses ALL text for `{{` and `}}` expression markers |
| "Validation errors = broken workflow" | Many "errors" are false positives for community nodes |
| "I can fix Merge connections via API" | API creates `type: "1"` instead of proper `type: "main"` - fix in UI |

## Node Type Prefixes

**Always include prefix:**
- Standard nodes: `nodes-base.webhook`, `nodes-base.httpRequest`
- LangChain nodes: `@n8n/n8n-nodes-langchain.agent`, `@n8n/n8n-nodes-langchain.lmChatOpenAi`

## n8n Expression Pitfalls

### Optional Chaining NOT Supported

**WRONG - n8n doesn't support `?.`:**
```javascript
={{ $json.data?.message?.text }}
```

**CORRECT - use explicit checks:**
```javascript
={{ ($json.data && $json.data.message) ? $json.data.message.text : '' }}
```

### Expression Bracket Escaping

**DANGER:** `}}` in any text field gets interpreted as expression closing brackets!

**WRONG - causes "unbalanced brackets" error:**
```
toolDescription: "Example: {\"name\": \"test\"}}"
```

**CORRECT - avoid `}}` in text or rephrase:**
```
toolDescription: "Example: name='test', type='г'"
```

### Merge Node Modes

**⚠️ CRITICAL:** Merge v3 has a TWO-LEVEL structure for modes!

**Valid top-level modes:**
- `append` - Append all items into one list
- `combine` - Combine items (requires `combineBy` sub-parameter!)
- `combineBySql` - SQL-based combination
- `chooseBranch` - Output from one selected input

**When using `mode: "combine"`, you MUST specify `combineBy`:**
- `combineByPosition` - Merge by array position (1st with 1st, etc.)
- `combineAll` - Combine all items from both inputs
- `mergeByFields` - Match by field values (**requires `fieldsToMatch`!**)

**WRONG - mode at wrong level:**
```json
{"mode": "combineByPosition"}  // ERROR: Invalid mode!
```

**CORRECT - two-level structure:**
```json
{"mode": "combine", "combineBy": "combineByPosition"}
```

**COMMON MISTAKE #1:** Using `combineByPosition` as top-level mode
```
Error: Invalid value for 'mode'. Must be one of: append, combine, combineBySql, chooseBranch
```
**FIX:** Use `mode: "combine"` with `combineBy: "combineByPosition"`

**COMMON MISTAKE #2:** Using `combine` with `mergeByFields` without `fieldsToMatch`:
```
Error: "You need to define at least one pair of fields in 'Fields to Match'"
```
**FIX:** Use `combineBy: "combineByPosition"` if you just want to merge by position without field matching.

## Partial Update Gotchas

### Connection Operation Parameters

**addConnection uses `source`/`target`, NOT `sourceNodeName`/`targetNodeName`:**
```javascript
// WRONG:
{type: "addConnection", sourceNodeName: "Node A", targetNodeName: "Node B"}

// CORRECT:
{type: "addConnection", source: "Node A", target: "Node B", sourceOutput: "0", targetInput: "1"}
```

**removeConnection uses `sourceNodeName`/`targetNodeName`:**
```javascript
{type: "removeConnection", sourceNodeName: "Node A", targetNodeName: "Node B", sourceOutput: "0", targetInput: "0"}
```

**Output/Input indices must be strings, not numbers:**
```javascript
// WRONG:
{sourceOutput: 0, targetInput: 1}

// CORRECT:
{sourceOutput: "0", targetInput: "1"}
```

### Node Names with Cyrillic/Special Characters

If node name contains special characters, use `nodeId` instead of `nodeName`:
```javascript
{type: "updateNode", nodeId: "807481ab-6779-4068-a774-e987ba31fe6b", updates: {...}}
```

### Merge Node Connections - DANGER ZONE

**⚠️ CRITICAL:** n8n-mcp API has LIMITATIONS with Merge node connections. When connections break, **FIX IN UI**, not via API!

**UI labels vs programmatic indices:**
- UI shows "Input 1" and "Input 2"
- Programmatically these are `targetInput: "0"` and `targetInput: "1"`

**The Problem:**
n8n stores Merge input connections with non-standard `type` values:
- `type: "main"` → Input 1 (index 0)
- `type: "1"` → Input 2 (index 1) - **NOT "main"!**

When API creates connection with `targetInput: "1"`, n8n internally stores it as `type: "1"`, which can cause UI rendering issues or broken connections.

**Signs of broken Merge connections:**
- Connections appear but workflow doesn't execute properly
- API shows `type: "1"` instead of `type: "main"` with `index: 1`
- Duplicate connection entries ("0" and "main" keys)

**RECOMMENDED: Fix Merge connections in n8n UI**
1. Open workflow in n8n UI
2. Delete broken connections manually
3. Reconnect nodes to correct Merge inputs
4. Save workflow

**If you must use API:**
```javascript
// Use removeConnection with ignoreErrors, then fix in UI
{type: "removeConnection", source: "Node", target: "Merge",
 sourceOutput: "0", targetInput: "1", ignoreErrors: true}
```

**WRONG - both to index 0:**
```
Node A → Merge (targetInput: "0" = UI "Input 1")
Node B → Merge (targetInput: "0" = UI "Input 1")  // Should be "1"!
```

**CORRECT:**
```
Node A → Merge (targetInput: "0" = UI "Input 1")
Node B → Merge (targetInput: "1" = UI "Input 2")
```

**cleanStaleConnections won't help** - it only removes connections to non-existent nodes, not malformed connections to existing nodes.

## Debugging Workflow Issues

### Step 1: Run Full Validation
```javascript
n8n_validate_workflow({id: "...", options: {
  validateNodes: true,
  validateConnections: true,
  validateExpressions: true,
  profile: "ai-friendly"
}})
```

### Step 2: Check Execution History for Context
If nodes appear empty but worked before:
```javascript
n8n_executions({action: "get", id: "<execution_id>", mode: "full"})
```

### Step 3: Check Version History
```javascript
n8n_workflow_versions({mode: "list", workflowId: "..."})
n8n_workflow_versions({mode: "get", workflowId: "...", versionId: <n>})
```

## Common Validation False Positives

These "errors" can be IGNORED:
- `Unknown node type: n8n-nodes-base.httpRequestTool` - valid AI tool type
- `Unknown node type: n8n-nodes-nats.natsTrigger` - community node
- `AI Agent has no systemMessage` - it's in `options.systemMessage`
- `Invalid mode: combineByPosition` - actually valid for Merge v3

These warnings are INFO only:
- `Outdated typeVersion` - update when convenient
- `Community node being used as AI tool` - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE setting
- `Using $json but node might not have input data` - expected for AI tools
