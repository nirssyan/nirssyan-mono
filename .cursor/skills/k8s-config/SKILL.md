---
name: k8s-config
description: Manage Kubernetes ConfigMaps (LLM models) and SealedSecrets (API keys) with git-first workflow. Use when updating AI agent models, rotating API keys, or checking configuration drift between git and cluster.
---

# Kubernetes Configuration Management

Manage ConfigMaps (LLM models) and SealedSecrets (API keys) with a git-first workflow.

## MANDATORY: Use Sonnet Subagent

**Delegate operations to a Sonnet subagent using the Task tool.**

## CRITICAL RULES FOR SUBAGENT

1. **GIT-FIRST** — always update git files first, then apply to cluster
2. **NO SECRET VALUES** — never display actual secret values, only key names
3. **CONFIRM BEFORE CHANGES** — ask for confirmation before any modifications
4. **COMMIT REMINDER** — always remind to commit changes after modifications
5. **PROD WARNINGS** — require explicit confirmation for production changes

## Subagent Invocation

```
Task(
    subagent_type="general-purpose",
    model="sonnet",
    description="K8s config management",
    prompt="""Manage Kubernetes ConfigMaps and SealedSecrets.

User command: {USER_COMMAND}
Environment: {ENV} (default: dev)

## CRITICAL RULES
- GIT-FIRST: Update git files first, then apply to cluster
- NO SECRET VALUES: Never show actual secret values
- CONFIRM before changes
- REMIND to commit after modifications
- PROD: Show warning and require 'yes' confirmation

## Environment Configuration

| Env | Namespace | Overlay Path |
|-----|-----------|--------------|
| dev | infatium-dev | overlays/dev |
| prod | infatium-prod | overlays/prod |

Kubeconfig: ~/.kube/nirssyan-infra.kubeconfig
Base path: /Users/svyatoslav/nirssyan-mono/infra/projects/infatium

## Key Files

- ConfigMap (models): `base/agents/configmap.yml`
- SealedSecrets: `overlays/{env}/service-secrets-sealed.yml`
- Public key: `sealed-secrets-pub.pem`

## Available Operations

### 1. SHOW MODELS (from git)
```bash
grep -E "(MODEL|BASE_URL):" /Users/svyatoslav/nirssyan-mono/infra/projects/infatium/base/agents/configmap.yml | grep -v "^#" | grep -v DATABASE_URL
```
Parse output and group by agent (MODEL + BASE_URL pairs).

### 2. SHOW MODELS CLUSTER (from live cluster)
```bash
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get configmap agents-config -n {namespace} -o yaml | grep "_MODEL:"
```

### 3. DIFF MODELS (compare git vs cluster)
Read both sources and show differences.

### 4. SET MODEL (update model for an agent)
Steps:
1. Read current git file
2. Show current value and new value
3. Ask for confirmation
4. Use Edit tool to update git file
5. Apply: `KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl apply -k overlays/{env}`
6. Restart: `KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl rollout restart deployment/makefeed-agents -n {namespace}`
7. Remind to commit

### 5. SHOW SECRETS (list keys only)
```bash
grep -E "^    [A-Z_]+:" /Users/svyatoslav/nirssyan-mono/infra/projects/infatium/overlays/{env}/service-secrets-sealed.yml | sed 's/:.*$//' | sed 's/^ *//'
```

### 6. SEAL VALUE (create sealed secret value)
```bash
printf '{VALUE}' > /tmp/secret.txt
kubeseal --raw --from-file=/tmp/secret.txt \
  --namespace {namespace} \
  --name service-secrets \
  --cert /Users/svyatoslav/nirssyan-mono/infra/projects/infatium/sealed-secrets-pub.pem
rm /tmp/secret.txt
```

### 7. ROTATE GROUP (update multiple keys)
For specified group, seal the new value and update each key in the group.
Groups:
- openrouter: VIEW_GENERATOR_API_KEY, FEED_FILTER_API_KEY, FEED_SUMMARY_API_KEY, UNSEEN_SUMMARY_API_KEY, POST_TITLE_API_KEY, FEED_TITLE_API_KEY
- mimo: VIEW_PROMPT_TRANSFORMER_API_KEY

### 8. RESTART (restart deployment)
```bash
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl rollout restart deployment/{deployment} -n {namespace}
```

### 9. STATUS (show pod status)
```bash
KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get pods -n {namespace} -l app.kubernetes.io/name={app}
```

## Agent Aliases (for models)

| Alias | ConfigMap Key |
|-------|---------------|
| view | VIEW_GENERATOR_MODEL |
| filter | FEED_FILTER_MODEL |
| summary | FEED_SUMMARY_MODEL |
| unseen | UNSEEN_SUMMARY_MODEL |
| title | POST_TITLE_MODEL |
| feed_title | FEED_TITLE_MODEL |
| transformer | VIEW_PROMPT_TRANSFORMER_MODEL |
| base | AI_MODEL |
| chat | CHAT_MESSAGE_MODEL |
| description | FEED_DESCRIPTION_MODEL |
| tags | FEED_TAGS_MODEL |
| comment | FEED_COMMENT_MODEL |

## Production Warning

For env=prod, show this warning:
```
⚠️ PRODUCTION ENVIRONMENT!
Namespace: infatium-prod
This will affect live users.
Type 'yes' to confirm changes:
```

## Output Format

For show operations, format as table with provider:
```
Agent                  | Model                                      | Provider
-----------------------|--------------------------------------------|------------
VIEW_GENERATOR         | google/gemini-3-flash-preview              | OpenRouter
FEED_FILTER            | deepseek/deepseek-v3.2                     | OpenRouter
VIEW_PROMPT_TRANSFORMER| mimo-v2-flash                              | MiMo API
```

Provider mapping:
- `openrouter.ai` → OpenRouter
- `xiaomimimo.com` → MiMo API
- `api.deepseek.com` → DeepSeek
- `api.openai.com` → OpenAI

For changes, show:
```
✅ Updated VIEW_GENERATOR_MODEL: old_value → new_value
📁 File: base/agents/configmap.yml
🔄 Restarted: makefeed-agents

⚠️ Don't forget to commit:
git add -A && git commit -m "chore: update VIEW_GENERATOR model to haiku"
```
"""
)
```

## Configuration

| Parameter | Value |
|-----------|-------|
| Kubeconfig | `~/.kube/nirssyan-infra.kubeconfig` |
| Base path | `/Users/svyatoslav/nirssyan-mono/infra/projects/infatium` |
| ConfigMap | `base/agents/configmap.yml` |
| SealedSecrets | `overlays/{env}/service-secrets-sealed.yml` |
| Public key | `sealed-secrets-pub.pem` |
| Default env | `dev` |

## Available Operations

| Command | Description |
|---------|-------------|
| `show models` | Show models from git |
| `show models cluster` | Show models from cluster |
| `diff models` | Compare git vs cluster |
| `set model AGENT VALUE` | Update model (git + cluster) |
| `show secrets` | List secret keys (no values) |
| `seal VALUE` | Create sealed value |
| `rotate GROUP VALUE` | Update key group |
| `restart DEPLOYMENT` | Restart deployment |
| `status` | Show pod status |

## Agent Aliases (for models)

| Alias | ConfigMap Key |
|-------|---------------|
| `view` | VIEW_GENERATOR_MODEL |
| `filter` | FEED_FILTER_MODEL |
| `summary` | FEED_SUMMARY_MODEL |
| `unseen` | UNSEEN_SUMMARY_MODEL |
| `title` | POST_TITLE_MODEL |
| `feed_title` | FEED_TITLE_MODEL |
| `transformer` | VIEW_PROMPT_TRANSFORMER_MODEL |
| `base` | AI_MODEL |
| `chat` | CHAT_MESSAGE_MODEL |
| `description` | FEED_DESCRIPTION_MODEL |
| `tags` | FEED_TAGS_MODEL |
| `comment` | FEED_COMMENT_MODEL |

## Secret Key Groups

| Group | Keys |
|-------|------|
| `openrouter` | VIEW_GENERATOR_API_KEY, FEED_FILTER_API_KEY, FEED_SUMMARY_API_KEY, UNSEEN_SUMMARY_API_KEY, POST_TITLE_API_KEY, FEED_TITLE_API_KEY |
| `mimo` | VIEW_PROMPT_TRANSFORMER_API_KEY |

## Environment Selection

Add `--env prod` or `--env dev` to commands:
- `/k8s-config show models --env prod`
- `/k8s-config set model view haiku --env prod`

Default is `dev`.

## Trigger Keywords

- "models", "модели", "llm" → model operations
- "secrets", "keys", "ключи", "api key" → secret operations
- "prod", "production", "прод" → env=prod
- "dev", "development", "дев" → env=dev
- "restart", "рестарт" → restart deployment
- "status", "статус", "pods" → status check
- "rotate", "ротация" → rotate secret group
