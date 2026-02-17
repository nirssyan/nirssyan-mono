---
name: infra
description: Use when making ANY infrastructure changes - enforces Infrastructure as Code by requiring all changes go through infra-startup git repo first, never direct kubectl mutations. Also manages ConfigMaps (LLM models) and SealedSecrets (API keys) with git-first workflow.
---

# Infrastructure Management

## Section 1: Infrastructure as Code (IaC) Principles

### Overview

**ALL cluster changes MUST go through infra-startup repo first.** Direct `kubectl patch/scale/edit` mutations are forbidden. Change code → commit → apply.

### The Iron Law

```
NO DIRECT KUBECTL MUTATIONS. EVER.
```

**Forbidden commands:**
- `kubectl patch` (use kustomize patches)
- `kubectl scale` (change replicas in manifests)
- `kubectl edit` (edit manifests in repo)
- `kubectl apply -f <inline>` (commit to repo first)
- `kubectl set` (change manifests)

**Allowed commands (read-only):**
- `kubectl get`, `describe`, `logs`, `top`, `exec`
- `kubectl apply -k <path-to-infra-startup>` (applying repo)
- `kubectl delete pod` (to restart, not permanent change)

### Workflow

```
1. Identify what needs to change
2. Find corresponding file in infra-startup/
3. Edit the file (kustomization.yml, deployment.yml, etc.)
4. kubectl apply -k <overlay-path> --dry-run=client
5. kubectl apply -k <overlay-path>
6. Verify change works
7. Commit to git
```

### Common Changes → Where to Edit

| Change | File Location |
|--------|---------------|
| Replicas | `projects/{project}/base/{service}/deployment.yml` |
| Memory/CPU requests | Same deployment.yml or kustomize patch |
| Secrets | Create SealedSecret in `overlays/{env}/` |
| ConfigMaps | `base/{service}/configmap.yml` |
| CronJob suspend | `global/backup/backup-cronjob.yml` |
| imagePullSecrets | Kustomize patch in `overlays/{env}/kustomization.yml` |
| Helm values | `ansible/helm-values/{chart}/values.yml` |

### Red Flags - STOP Immediately

If you're about to run any of these, STOP:

- `kubectl patch deployment` → Edit deployment.yml instead
- `kubectl scale` → Change `replicas:` in manifest
- `kubectl patch sts` → Edit statefulset.yml instead
- `kubectl patch cronjob` → Edit cronjob.yml instead
- "I'll add it to infra-startup later" → NO. Add it NOW, then apply
- "This is temporary" → Temporary changes get forgotten. Use git.
- "It's urgent" → Taking 2 extra minutes to edit file prevents hours of drift debugging

### Rationalizations Table

| Excuse | Reality |
|--------|---------|
| "It's urgent, need to fix now" | 2 min to edit file. Drift causes hours of debugging later. |
| "I'll commit later" | You won't. Or you'll forget what you changed. |
| "This is temporary" | Nothing is temporary. Temporary = permanent undocumented. |
| "Just testing if it works" | Test in file, apply, rollback via git if needed. |
| "Too small to matter" | Small changes accumulate. Drift is death by 1000 cuts. |
| "Emergency situation" | Emergencies need audit trail most. Use git. |

### Quick Reference: infra-startup Structure

```
infra-startup/
├── projects/{project}/
│   ├── base/           # Shared manifests (deployment, service, configmap)
│   └── overlays/
│       ├── dev/        # Dev patches, sealed secrets
│       └── prod/       # Prod patches, sealed secrets
├── global/             # Cluster-wide services (backup, registry, n8n)
└── ansible/helm-values/  # Helm chart configurations
```

### Example: Scaling a Deployment

**❌ WRONG:**
```bash
kubectl scale deployment n8n -n infrastructure --replicas=1
```

**✅ CORRECT:**
```bash
# 1. Edit manifest
vim infra-startup/global/n8n/deployment.yml
# Change: replicas: 3 → replicas: 1

# 2. Apply
kubectl apply -k infra-startup/global/n8n/

# 3. Commit
cd infra-startup && git add -A && git commit -m "n8n: scale to 1 replica"
```

### Example: Changing Memory Requests

**❌ WRONG:**
```bash
kubectl patch sts loki-chunks-cache -n infrastructure --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "128Mi"}]'
```

**✅ CORRECT:**
```bash
# 1. Find helm values (Loki is Helm-managed)
vim infra-startup/ansible/helm-values/loki/values.yml
# Change chunksCache.resources.requests.memory

# 2. Apply via Helm
helm upgrade loki grafana/loki -n infrastructure -f ansible/helm-values/loki/values.yml

# 3. Commit
git add -A && git commit -m "loki: reduce chunks-cache memory to 128Mi"
```

### Example: Adding Secret

**❌ WRONG:**
```bash
kubectl create secret generic my-secret -n infatium-dev --from-literal=KEY=value
```

**✅ CORRECT:**
```bash
# 1. Create sealed secret
echo -n 'value' | kubeseal --raw --namespace infatium-dev --name my-secret \
  --cert infra-startup/projects/infatium/sealed-secrets-pub.pem

# 2. Create sealed secret file
vim infra-startup/projects/infatium/overlays/dev/my-secret-sealed.yml

# 3. Add to kustomization.yml resources

# 4. Apply
kubectl apply -k infra-startup/projects/infatium/overlays/dev/

# 5. Commit
git add -A && git commit -m "Add my-secret to infatium-dev"
```

### Verification After Changes

After applying from infra-startup, verify:
1. `kubectl get <resource>` shows expected state
2. Pods are running/healthy
3. No drift: `kubectl diff -k <path>` shows no differences

### Recovery: Already Made Direct Change?

If you already mutated directly:

1. **Document what you changed** (kubectl get -o yaml)
2. **Replicate in infra-startup** immediately
3. **Apply from repo** to ensure repo matches cluster
4. **Commit**
5. **Add to this skill** if it's a new pattern

### Bottom Line

**Infrastructure as Code means CODE FIRST.**

Every `kubectl patch/scale/edit` is technical debt. Every direct mutation is a future incident waiting to happen.

Change the file. Apply the file. Commit the file. Always.

## Section 2: ConfigMap/Secrets Operations

### MANDATORY: Use Sonnet Subagent

**Delegate operations to a Sonnet subagent using the Task tool.**

### CRITICAL RULES FOR SUBAGENT

1. **GIT-FIRST** — always update git files first, then apply to cluster
2. **NO SECRET VALUES** — never display actual secret values, only key names
3. **CONFIRM BEFORE CHANGES** — ask for confirmation before any modifications
4. **COMMIT REMINDER** — always remind to commit changes after modifications
5. **PROD WARNINGS** — require explicit confirmation for production changes

### Subagent Invocation

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
Base path: /Users/svyatoslav/nirssyan/infra-startup/projects/infatium

## Key Files

- ConfigMap (models): `base/agents/configmap.yml`
- SealedSecrets: `overlays/{env}/service-secrets-sealed.yml`
- Public key: `sealed-secrets-pub.pem`

## Available Operations

### 1. SHOW MODELS (from git)
```bash
grep -E "(MODEL|BASE_URL):" /Users/svyatoslav/nirssyan/infra-startup/projects/infatium/base/agents/configmap.yml | grep -v "^#" | grep -v DATABASE_URL
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
grep -E "^    [A-Z_]+:" /Users/svyatoslav/nirssyan/infra-startup/projects/infatium/overlays/{env}/service-secrets-sealed.yml | sed 's/:.*$//' | sed 's/^ *//'
```

### 6. SEAL VALUE (create sealed secret value)
```bash
printf '{VALUE}' > /tmp/secret.txt
kubeseal --raw --from-file=/tmp/secret.txt \
  --namespace {namespace} \
  --name service-secrets \
  --cert /Users/svyatoslav/nirssyan/infra-startup/projects/infatium/sealed-secrets-pub.pem
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

### Configuration

| Parameter | Value |
|-----------|-------|
| Kubeconfig | `~/.kube/nirssyan-infra.kubeconfig` |
| Base path | `/Users/svyatoslav/nirssyan/infra-startup/projects/infatium` |
| ConfigMap | `base/agents/configmap.yml` |
| SealedSecrets | `overlays/{env}/service-secrets-sealed.yml` |
| Public key | `sealed-secrets-pub.pem` |
| Default env | `dev` |

### Available Operations

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

### Secret Key Groups

| Group | Keys |
|-------|------|
| `openrouter` | VIEW_GENERATOR_API_KEY, FEED_FILTER_API_KEY, FEED_SUMMARY_API_KEY, UNSEEN_SUMMARY_API_KEY, POST_TITLE_API_KEY, FEED_TITLE_API_KEY |
| `mimo` | VIEW_PROMPT_TRANSFORMER_API_KEY |

### Environment Selection

Add `--env prod` or `--env dev` to commands:
- `/infra show models --env prod`
- `/infra set model view haiku --env prod`

Default is `dev`.

### Trigger Keywords

- "models", "модели", "llm" → model operations
- "secrets", "keys", "ключи", "api key" → secret operations
- "prod", "production", "прод" → env=prod
- "dev", "development", "дев" → env=dev
- "restart", "рестарт" → restart deployment
- "status", "статус", "pods" → status check
- "rotate", "ротация" → rotate secret group
