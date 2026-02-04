# go-poller

Go сервис для polling RSS и Web источников. Заменяет Python сервисы `makefeed_rss` и `makefeed_web`.

## Преимущества Go версии

- **RAM**: 100-150 MB → 20-30 MB
- **Docker image**: 500 MB → 20 MB
- **Startup**: 2-3 сек → <200 мс
- **Один deployment** вместо двух

## Архитектура

```
cmd/poller/main.go           # Entry point
internal/
├── app/app.go               # DI container, lifecycle
├── config/config.go         # Env configuration
├── domain/                  # Domain models
├── rss/                     # RSS polling
│   ├── parser.go           # gofeed + trafilatura
│   ├── content.go          # Content enrichment
│   └── poller.go           # Background poller
└── web/                     # Web polling
    ├── discovery/          # 5-step discovery pipeline
    ├── media/              # Media extraction + logo filter
    ├── poller.go           # Background poller
    └── validation.go       # NATS request-reply handler
pkg/
├── db/                     # PostgreSQL pool
├── http/                   # Polite HTTP client
├── nats/                   # NATS JetStream
├── moderation/             # HTTP client to Python
└── observability/          # OTEL + Prometheus
repository/                 # Data access
```

## Feature Flags

Сервис поддерживает feature flags для постепенной миграции:

```bash
# Только RSS polling
RSS_POLLING_ENABLED=true
WEB_POLLING_ENABLED=false

# Только Web polling
RSS_POLLING_ENABLED=false
WEB_POLLING_ENABLED=true

# Оба сервиса (по умолчанию)
RSS_POLLING_ENABLED=true
WEB_POLLING_ENABLED=true
```

## Запуск

### Локально

```bash
# Установить зависимости
go mod download

# Запустить (требуется .env)
go run ./cmd/poller

# Только RSS
RSS_POLLING_ENABLED=true WEB_POLLING_ENABLED=false go run ./cmd/poller
```

### Docker

```bash
# Build
docker build -t makefeed-go-poller .

# Run
docker run --env-file .env makefeed-go-poller
```

## Endpoints

| Endpoint | Описание |
|----------|----------|
| `GET /healthz` | Liveness probe |
| `GET /readyz` | Readiness probe (проверяет DB) |
| `GET /metrics` | Prometheus metrics |

## Prometheus Metrics

```promql
# Counters
feeds_polled_total{source="rss|web", status="success|error"}
posts_created_total{source="rss|web"}
nats_messages_published_total{subject}
moderation_requests_total{status}
http_requests_total{domain, status}

# Histograms
poll_duration_seconds{source, tier}
content_fetch_duration_seconds{source}
discovery_step_duration_seconds{step}
```

## NATS Subjects

| Subject | Описание |
|---------|----------|
| `posts.new.rss` | Новые RSS посты |
| `posts.new.web` | Новые Web посты |
| `web.validate` | Request-reply для валидации URL |

## Discovery Pipeline

Web discovery использует 5-step pipeline:

1. **RSS_FEEDPARSER** - Проверяем, является ли URL RSS лентой
2. **RSS_ENDPOINTS** - Ищем RSS по стандартным эндпоинтам (/feed, /rss, etc.)
3. **SITEMAP** - Парсим sitemap.xml
4. **HTML** - Извлекаем ссылки из HTML
5. **TRAFILATURA** - Extraction через trafilatura

## Tier-based Polling

Feeds автоматически перемещаются между tiers:

| Tier | Интервал (RSS) | Интервал (Web) | Условие |
|------|---------------|----------------|---------|
| HOT | 5 мин | 10 мин | Есть новые посты |
| WARM | 10 мин | 30 мин | Нет новых постов |
| COLD | 1 час | 2 часа | Долго нет постов |
| QUARANTINE | 4 часа | 8 часов | 5+ ошибок подряд |

## Модерация

Модерация делегируется в Python сервис через HTTP:

```bash
MODERATION_SERVICE_URL=http://makefeed-api:8000
```

Это позволяет:
- Использовать сложную логику Python модерации
- Не дублировать код
- Постепенно мигрировать
