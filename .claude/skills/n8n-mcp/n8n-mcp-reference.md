# n8n MCP Reference

## Оптимизация контекста (ВАЖНО!)

### Проблема
Полный workflow JSON занимает много токенов. Workflow `aSUAGHHW2ZdojljS` (~37 нод) = тысячи токенов.

### Решение: n8n-summary-mcp (Рекомендуемый подход)

**ВСЕГДА начинай с `n8n_workflow_summary`!**

```javascript
// 1. Получи обзор workflow (ASCII диаграмма + список нод по категориям)
n8n_workflow_summary({workflowId: "aSUAGHHW2ZdojljS"})  // ~500-1K токенов

// 2. Получи конфиг конкретной ноды
n8n_get_node({workflowId: "aSUAGHHW2ZdojljS", nodeName: "Order Proposal Pending Agent"})  // ~200-500 токенов

// 3. Поиск по содержимому нод
n8n_search_workflow({workflowId: "aSUAGHHW2ZdojljS", query: "scenario"})
```

#### Сравнение инструментов

| Инструмент | Токены (~37 нод) | Когда использовать |
|------------|------------------|-------------------|
| `n8n_workflow_summary` | ~500-1K | **ПЕРВЫЙ ШАГ** - обзор workflow |
| `n8n_get_node` (один) | ~200-500 | Конфиг конкретной ноды |
| `n8n_search_workflow` | ~200-1K | Поиск по параметрам нод |
| `n8n_get_workflow({mode: "structure"})` | ~2-3K | Если нужны все ноды сразу |
| `n8n_get_workflow({mode: "full"})` | ~8-15K | **ИЗБЕГАЙ** - только для settings |

```javascript
// ❌ ПЛОХО - тратит токены
n8n_get_workflow({id: "...", mode: "full"})

// ✅ ХОРОШО - сначала обзор, потом конкретная нода
n8n_workflow_summary({workflowId: "..."})
n8n_get_node({workflowId: "...", nodeName: "Order Agent"})
```

### Когда использовать n8n_get_workflow
- `mode: "structure"` - если нужны ВСЕ ноды и connections
- `mode: "minimal"` - только статус workflow
- `mode: "full"` - только если нужны workflow settings

#### Уровень 2: Partial updates вместо полной замены

```javascript
// ❌ Плохо - читаем весь JSON, меняем, пишем весь JSON
const workflow = n8n_get_workflow({id: "...", mode: "full"})
// ... изменяем ...
n8n_update_full_workflow({id: "...", nodes: [...], connections: {...}})

// ✅ Хорошо - только целевое изменение
n8n_update_partial_workflow({
  id: "aSUAGHHW2ZdojljS",
  operations: [{
    type: "updateNode",
    nodeName: "Order Proposal Pending Agent",
    updates: {
      parameters: {
        options: { systemMessage: "новый промпт..." }
      }
    }
  }]
})
```

#### Уровень 3: Локальные XML как источник правды

Промпты хранятся в `workflow/prompts/*.xml` (~1-2K токенов каждый).

**Рабочий процесс:**
1. Читаем XML файл (маленький)
2. Редактируем XML
3. Синхронизируем в n8n через partial update

```javascript
// Синхронизация промпта из XML в n8n
n8n_update_partial_workflow({
  id: "aSUAGHHW2ZdojljS",
  operations: [{
    type: "updateNode",
    nodeName: "Order Proposal Pending Agent",
    updates: {
      parameters: {
        options: { systemMessage: "<содержимое XML>" }
      }
    }
  }]
})
```

### Маппинг агентов workflow aSUAGHHW2ZdojljS

| XML файл | Node name | Scenario |
|----------|-----------|----------|
| `no_scenario.xml` | `start` | start |
| `order_proposal_pending.xml` | `Order Proposal Pending Agent` | order_proposal.pending |
| `order_proposal_unsubscribe.xml` | `Order Proposal Unsubscribe Agent` | order_proposal.unsubscribe |
| `order_proposal_other_route.xml` | `Order Proposal Other Route Agent` | order_proposal.other_route |
| `order_proposal_low_bid.xml` | `Order Proposal Low Bid Agent` | order_proposal.low_bid |
| `order_proposal_reject_reason.xml` | `Order Proposal Reject Reason Agent` | order_proposal.reject_reason |
| `active_truck_creation.xml` | `Active truck Creation` | active_truck.creation |
| `active_truck_recommendations.xml` | `Active Truck Recommendations Agent` | active_truck.recommendations |

---

## n8n-summary-mcp Tools (Token-Efficient)

| Tool | Purpose | Tokens | Key Params |
|------|---------|--------|------------|
| `n8n_workflow_summary` | ASCII диаграмма + список нод | ~500-1K | `workflowId` |
| `n8n_get_node` | Конфиг одной ноды | ~200-500 | `workflowId`, `nodeName` |
| `n8n_search_workflow` | Поиск по параметрам нод | ~200-1K | `workflowId`, `query` |

**Когда использовать:**
- `n8n_workflow_summary` - всегда первый шаг, понять структуру
- `n8n_get_node` - получить systemMessage или параметры конкретной ноды
- `n8n_search_workflow` - найти где используется переменная/сценарий

---

## All n8n-mcp Tools by Category

### Discovery
| Tool | Purpose | Key Params |
|------|---------|------------|
| `search_nodes` | Search 500+ nodes | `query`, `mode: OR/AND/FUZZY`, `limit` |
| `get_node` | Get node schema | `nodeType`, `detail: minimal/standard/full`, `mode: info/docs/search_properties` |

### Validation
| Tool | Purpose | Key Params |
|------|---------|------------|
| `validate_node` | Validate single node | `nodeType`, `config`, `profile: runtime`, `mode: full/minimal` |
| `validate_workflow` | Validate full workflow | `workflow`, `options: {validateNodes, validateConnections, validateExpressions}` |

### Templates
| Tool | Purpose | Key Params |
|------|---------|------------|
| `search_templates` | Search 2700+ templates | `searchMode: keyword/by_nodes/by_task/by_metadata` |
| `get_template` | Get template JSON | `templateId`, `mode: nodes_only/structure/full` |

### Workflow Management
| Tool | Purpose | Key Params |
|------|---------|------------|
| `n8n_create_workflow` | Create new workflow | `name`, `nodes[]`, `connections{}` |
| `n8n_get_workflow` | Read workflow | `id`, `mode: minimal/structure/full/details` |
| `n8n_update_partial_workflow` | **Incremental update** | `id`, `operations[]`, `validateOnly`, `continueOnError` |
| `n8n_update_full_workflow` | Full replacement | `id`, `nodes[]`, `connections{}` |
| `n8n_delete_workflow` | Delete workflow | `id` |
| `n8n_list_workflows` | List workflows | `active`, `tags[]`, `cursor` |
| `n8n_validate_workflow` | Validate by ID | `id`, `options` |
| `n8n_autofix_workflow` | Auto-fix issues | `id`, `applyFixes`, `confidenceThreshold` |
| `n8n_test_workflow` | Test/trigger workflow | `workflowId`, `triggerType`, `data` |

### Execution & History
| Tool | Purpose | Key Params |
|------|---------|------------|
| `n8n_executions` | Manage executions | `action: get/list/delete`, `id`, `mode` |
| `n8n_workflow_versions` | Version history | `mode: list/get/rollback/delete/prune` |
| `n8n_deploy_template` | Deploy from n8n.io | `templateId`, `autoFix`, `stripCredentials` |

### System
| Tool | Purpose | Key Params |
|------|---------|------------|
| `tools_documentation` | Get tool docs | `topic`, `depth: essentials/full` |
| `n8n_health_check` | Check API health | `mode: status/diagnostic` |

## Detail Levels (get_node)

| Level | Tokens | Use When |
|-------|--------|----------|
| `minimal` | ~200 | Quick metadata check |
| `standard` | ~1-2K | **95% of cases - START HERE** |
| `full` | ~3-8K | When standard isn't enough |

## Validation Profiles

| Profile | Strictness | Use When |
|---------|------------|----------|
| `minimal` | Low | Quick iteration |
| `runtime` | Medium | **Default - use this** |
| `ai-friendly` | Medium | AI workflows |
| `strict` | High | Production deployment |

## Partial Update Operations (17 types)

### Node Operations
```javascript
{type: "addNode", node: {...}}
{type: "removeNode", nodeName: "NodeName"}
{type: "updateNode", nodeName: "NodeName", updates: {parameters: {...}}}
{type: "moveNode", nodeName: "NodeName", position: [x, y]}
{type: "enableNode", nodeName: "NodeName"}
{type: "disableNode", nodeName: "NodeName"}
```

### Connection Operations
```javascript
{type: "addConnection", from: "Source", to: "Target", sourceOutput: "main", targetInput: "main"}
{type: "removeConnection", from: "Source", to: "Target"}
{type: "rewireConnection", from: "Source", oldTarget: "Old", newTarget: "New"}
{type: "cleanStaleConnections"}
{type: "replaceConnections", connections: {...}}
```

### Metadata Operations
```javascript
{type: "updateSettings", settings: {...}}
{type: "updateName", name: "New Name"}
{type: "addTag", tag: "tag-name"}
{type: "removeTag", tag: "tag-name"}
{type: "activateWorkflow"}
{type: "deactivateWorkflow"}
```

### Smart Parameters
- **IF node:** `branch: "true"` or `branch: "false"`
- **Switch node:** `case: 0`, `case: 1`, etc.

## AI Connection Types (8 types)

| Type | From | To | Required |
|------|------|----|---------|
| `ai_languageModel` | OpenAI, Anthropic | AI Agent | **REQUIRED** |
| `ai_tool` | HTTP Tool, Code Tool | AI Agent | Min 1 |
| `ai_memory` | Buffer, Summary Memory | AI Agent | Optional |
| `ai_outputParser` | JSON Parser, Structured | AI Agent | Optional |
| `ai_embedding` | OpenAI Embeddings | Vector Store | For RAG |
| `ai_vectorStore` | Pinecone, Qdrant | Vector Store Tool | For RAG |
| `ai_document` | Document Loader | Vector Store | For RAG |
| `ai_textSplitter` | Text Splitter | Document chain | Optional |

### AI Connection Example
```javascript
{
  type: "addConnection",
  from: "OpenAI Chat Model",
  to: "AI Agent",
  sourceOutput: "ai_languageModel",  // REQUIRED for AI
  targetInput: "ai_languageModel"
}
```

## Auto-Sanitization (automatic)

**What it fixes:**
- Binary operators → removes `singleValue`
- Unary operators → adds `singleValue: true`
- IF/Switch nodes → adds `conditions.options` structure
- Webhook nodes → generates `webhookId`

**What it CAN'T fix:**
- Broken connections (use `cleanStaleConnections`)
- Branch count mismatches
- Paradoxical corrupt states

## Autofix Types

| Fix Type | What It Does |
|----------|--------------|
| `expression-format` | Adds missing `=` prefix |
| `typeversion-correction` | Fixes typeVersion mismatches |
| `error-output-config` | Configures error outputs |
| `node-type-correction` | Fixes node type names |
| `webhook-missing-path` | Adds missing webhook paths |
| `typeversion-upgrade` | Upgrades to latest version |
| `version-migration` | Migrates deprecated configs |

## Workflow Creation Example

```javascript
// 1. Search nodes
search_nodes({query: "webhook slack", limit: 5})

// 2. Get configs
get_node({nodeType: "nodes-base.webhook", detail: "standard"})
get_node({nodeType: "nodes-base.slack", detail: "standard"})

// 3. Validate nodes
validate_node({nodeType: "nodes-base.webhook", config: {...}})

// 4. Create
n8n_create_workflow({
  name: "Webhook to Slack",
  nodes: [
    {id: "wh", name: "Webhook", type: "n8n-nodes-base.webhook", typeVersion: 2, position: [250, 300], parameters: {path: "test"}},
    {id: "slack", name: "Slack", type: "n8n-nodes-base.slack", typeVersion: 2.2, position: [450, 300], parameters: {channel: "#alerts", text: "={{ $json.message }}"}}
  ],
  connections: {
    "Webhook": {main: [[{node: "Slack", type: "main", index: 0}]]}
  }
})

// 5. Autofix (preview)
n8n_autofix_workflow({id: "...", applyFixes: false})

// 6. Autofix (apply)
n8n_autofix_workflow({id: "...", applyFixes: true})
```
