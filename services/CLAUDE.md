# Services

Все микросервисы платформы Infatium.

## Go Services

### Patterns
- **Router**: chi/v5 с middleware для auth, CORS, logging
- **Database**: pgx/v5 connection pool
- **Logging**: zerolog с structured logging
- **Config**: envconfig для environment variables
- **Error tracking**: Sentry SDK (GlitchTip compatible)

### Structure
Каждый Go сервис имеет структуру:
```
go-{service}/
├── cmd/{service}/main.go     # Entrypoint
├── internal/
│   ├── app/app.go           # Application setup
│   ├── config/config.go     # Configuration
│   ├── handlers/            # HTTP handlers
│   ├── middleware/          # HTTP middleware
│   └── services/            # Business logic
├── pkg/
│   ├── db/                  # Database utilities
│   ├── nats/                # NATS client
│   └── observability/       # Tracing, metrics
├── repository/              # Data access layer
├── Dockerfile
├── go.mod
└── go.sum
```

### NATS Communication
Сервисы общаются через NATS JetStream:
- `go-poller` → публикует raw posts
- `go-processor` → обрабатывает raw posts, вызывает agents
- `agents` → отвечает на RPC запросы
- `go-api` → WebSocket уведомления

## Python Services

### Patterns
- **Messaging**: FastStream с NATS backend
- **AI**: LangChain для агентов
- **Database**: SQLAlchemy async
- **Logging**: loguru

### Structure
```
{service}/
├── {service}/
│   ├── __init__.py
│   ├── main.py              # Entrypoint
│   ├── config.py            # Configuration
│   ├── handlers/            # Message handlers
│   └── ai_agents/           # AI agent classes
├── pyproject.toml
└── Dockerfile
```

### shared-python
Общий код для Python сервисов:
- `shared.database` - SQLAlchemy tables, connection
- `shared.models` - Pydantic models
- `shared.repositories` - Data access
- `shared.events` - NATS event schemas
- `shared.nats` - NATS client utilities
- `shared.faststream` - FastStream helpers

## Communication Flow

```
Telegram/RSS/Web
       ↓
  go-poller (polling, parsing)
       ↓ NATS: raw_posts.created
  go-processor (filtering, calling agents)
       ↓ NATS RPC: agents.{type}
  agents (AI processing)
       ↓
  go-processor (saves posts)
       ↓ NATS: posts.created
  go-api (notifies clients via WebSocket)
```
