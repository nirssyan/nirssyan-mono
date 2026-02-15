# Infatium Monorepo

## MANDATORY: Use td for Task Management

Run td usage --new-session at conversation start (or after /clear). This tells you what to work on next.

Sessions are automatic (based on terminal/agent context). Optional:
- td session "name" to label the current session
- td session --new to force a new session in the same context

Use td usage -q after first read.

Монорепозиторий для платформы персонализированных новостных лент Infatium/Makefeed.

## Git Branch Convention

- Фикс **prod** → ветка от `master`, PR в `master`
- Фикс **dev** / новая фича → ветка от `develop`, PR в `develop`

## СТРОГОЕ ПРАВИЛО: Telegram-сессии DEV и PROD должны быть РАЗНЫМИ

**НИКОГДА не используй одну и ту же Telegram-сессию (аккаунт) одновременно в dev и prod!**

- Dev и prod ОБЯЗАНЫ использовать РАЗНЫЕ Telegram-аккаунты (разные телефоны, разные auth_key)
- При деплое новой сессии — ВСЕГДА проверяй, что она НЕ совпадает с сессией в другом окружении
- Файлы: `dev_session.session` (dev) и `prod_session.session` (prod) — это РАЗНЫЕ аккаунты
- Причина: два клиента с одним auth_key = конфликт сессий, один из клиентов будет отключён Telegram

**Проверка перед деплоем:**
```bash
# Сравнить AuthKeyID — должны ОТЛИЧАТЬСЯ
cat services/go-poller/.telegram/dev_session.session | python3 -c "import sys,json; print('DEV:', json.load(sys.stdin)['Data']['AuthKeyID'])"
kubectl exec -n infatium-prod <pod> -- cat /app/.telegram/prod_session.session | python3 -c "import sys,json; print('PROD:', json.load(sys.stdin)['Data']['AuthKeyID'])"
```

## Структура репозитория

```
infatium-mono/
├── services/              # Все сервисы
│   ├── go-api/           # REST API (Go, chi router)
│   ├── go-processor/     # NATS consumers, обработка постов
│   ├── go-registry/      # Синхронизация LLM моделей
│   ├── go-poller/        # RSS/Web/Telegram polling
│   ├── go-integrations/  # Webhooks (AppStore, Sentry)
│   ├── agents/           # AI агенты (Python, LangChain)
│   ├── integrations/     # Python webhooks (deprecated)
│   └── shared-python/    # Общий Python код
│
├── web/
│   └── landing/          # Landing page (Next.js)
│
├── infra/                # Infrastructure as Code
│   ├── ansible/          # Ansible playbooks
│   ├── global/           # Общие Helm values
│   └── projects/         # K8s manifests (Kustomize)
│
└── database/
    └── migrations/       # Alembic migrations
```

## Quick Commands

### Go Services
```bash
# go-api
cd services/go-api && go test -v ./... && go run ./cmd/api

# go-processor
cd services/go-processor && go test -v ./... && go run ./cmd/processor

# go-registry
cd services/go-registry && go test -v ./... && go run ./cmd/registry

# go-poller
cd services/go-poller && go test -v ./... && go run ./cmd/poller

# go-integrations
cd services/go-integrations && go test -v ./... && go run ./cmd/integrations
```

### Python Services
```bash
# agents
cd services/agents && rye sync && rye run infatium-agents

# integrations
cd services/integrations && rye sync && rye run infatium-integrations
```

### Landing
```bash
cd web/landing && npm install && npm run dev
```

### Infrastructure
```bash
cd infra && ./deploy -p infatium -e dev
```

## CI/CD

Каждый сервис имеет свой workflow с path filters:

| Изменение | Workflow |
|-----------|----------|
| `services/go-api/**` | ci-go-api.yml |
| `services/go-processor/**` | ci-go-processor.yml |
| `services/go-registry/**` | ci-go-registry.yml |
| `services/go-poller/**` | ci-go-poller.yml |
| `services/go-integrations/**` | ci-go-integrations.yml |
| `services/agents/**` | ci-agents.yml |
| `services/shared-python/**` | ci-agents.yml |
| `web/landing/**` | ci-landing.yml |

## Kubernetes

```bash
# Kubeconfig
export KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig

# Pods
kubectl get pods -n infatium-dev

# Logs
kubectl logs -n infatium-dev deployment/go-api --tail=100

# Restart
kubectl rollout restart -n infatium-dev deployment/go-api
```

## Key Technologies

### Go Services
- Router: `github.com/go-chi/chi/v5`
- Database: `github.com/jackc/pgx/v5`
- NATS: `github.com/nats-io/nats.go`
- Logging: `github.com/rs/zerolog`
- Config: `github.com/kelseyhightower/envconfig`

### Python Services
- AI: LangChain, LangChain-OpenAI
- Messaging: FastStream (NATS)
- Database: SQLAlchemy + asyncpg

### Infrastructure
- Kubernetes с Kustomize overlays
- Sealed Secrets для секретов
- Prometheus + Grafana для мониторинга

## Environment Variables

Все сервисы используют общие переменные:
- `DATABASE_URL` - PostgreSQL connection string
- `NATS_URL` - NATS server URL
- `SENTRY_DSN` / `GLITCHTIP_DSN` - Error tracking
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector

## Database Migrations

**ВАЖНО: Все миграции БД делать ТОЛЬКО через Alembic. Никогда не применять SQL напрямую к БД.**

```bash
cd database/migrations
rye run alembic upgrade head
rye run alembic revision --autogenerate -m "description"
```

## Backups

Конфигурация: `infra/global/backup/`
Playbooks: `infra/ansible/playbooks/backups/`

```bash
cd infra/ansible

# Ручной бэкап (создаёт Job из CronJob)
ansible-playbook -i inventory/hosts.yml playbooks/backups/backup.yml

# Список бэкапов (локальные + Yandex Disk)
ansible-playbook -i inventory/hosts.yml playbooks/backups/list-backups.yml

# Полный рестор из Yandex Disk (non-interactive, full DR)
ansible-playbook -i inventory/hosts.yml playbooks/backups/restore-full.yml

# Рестор конкретного бэкапа
ansible-playbook -i inventory/hosts.yml playbooks/backups/restore-full.yml \
  -e "backup_file=2024/03/backup-2024-03-15.tar.zst.age"

# Только DB для одного namespace
ansible-playbook -i inventory/hosts.yml playbooks/backups/restore-full.yml \
  -e "target_namespace=infatium-dev skip_k3s=true skip_secrets=true skip_pvc=true"

# Интерактивный рестор (выбор источника, scope)
ansible-playbook -i inventory/hosts.yml playbooks/backups/restore.yml
```

Лейблы для подов:
- `backup.infra/type: "database"` + `backup.infra/db-type: "postgresql|mysql|mongodb|redis"` — DB дамп
- `backup.infra/enabled: "false"` — opt-out из PVC бэкапа

## Feed Business Flow

### 1. Создание ленты

`POST /feeds/create` (go-api) → создаёт:
- `feeds` — лента пользователя (name, type: SINGLE_POST/DIGEST)
- `prompts` — AI конфигурация (views_config, filters_config)
- `prompts_raw_feeds` — связь prompt ↔ raw_feed (источник)
- `prompts_raw_feeds_offsets` — offset tracking для каждой пары prompt+raw_feed

NATS events:
- `feeds.created` → go-processor: генерация описания, трансформация views/filters, trigger initial sync
- `feeds.initial_sync` → go-processor: берёт N последних raw_posts и обрабатывает

### 2. Поллинг (go-poller)

Тиры: FAST (1 мин), REGULAR (10 мин), SLOW (1 час), BACKGROUND (6 часов).
Источники: Telegram (MTProto), RSS (gofeed), Website (scraper).

Pipeline: poll → parse → dedup (rp_unique_code) → save raw_posts → NATS `posts.new.{raw_type}`

Дедупликация на уровне go-poller:
- `rp_unique_code` — уникальный код из источника (telegram: `tg_{chat_id}_{msg_id}`, rss: hash URL)
- In-batch seen map для одного цикла поллинга
- `ON CONFLICT (rp_unique_code) DO NOTHING` — DB-level safety net

### 3. Обработка (go-processor)

Подписка на `posts.new.*` + `feeds.created` + `feeds.initial_sync`.

Для каждого raw_post × prompt:
1. **Filter** — AI agent оценивает релевантность (`agents.evaluate_post`)
2. **Views** — AI генерит представления по views_config (`agents.generate_view`)
3. **Title** — AI генерит заголовок (`agents.generate_post_title`)
4. **Save** — `INSERT INTO posts ... ON CONFLICT (feed_id, raw_post_id) DO NOTHING`

Дедупликация на уровне go-processor:
- `posts.raw_post_id` + partial unique index `(feed_id, raw_post_id) WHERE raw_post_id IS NOT NULL`
- Один raw_post = максимум один post в каждой ленте

Offset tracking:
- `prompts_raw_feeds_offsets.last_processed_created_at` — timestamp-based
- Запрос unprocessed: `rp.created_at > offset_created_at` (не UUID comparison)

### 4. Связи таблиц

```
raw_feeds (источники: Telegram каналы, RSS, Web)
  └── raw_posts (сырые посты из источников)
        └── posts.raw_post_id → raw_posts.id

feeds (ленты пользователей)
  └── prompts (AI конфигурация)
        └── prompts_raw_feeds (связь с источниками)
              └── prompts_raw_feeds_offsets (progress tracking)
        └── posts (обработанные посты)
              └── sources (ссылки на оригинал)
```

### 5. Типы лент

- **SINGLE_POST** — каждый raw_post обрабатывается индивидуально → один post
- **DIGEST** — периодическая сводка из нескольких raw_posts → один digest post
