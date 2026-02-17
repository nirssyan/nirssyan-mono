---
name: frontend-debug
description: Debug frontend issues by searching backend logs and making API requests. Use when frontend developer pastes logs with user-id, feed-id, or describes an issue.
---

# Frontend Debug Skill

Отладка проблем фронтенда через поиск логов бекенда и запросы к API.

## Когда использовать

- Фронт присылает лог с ошибкой
- Нужно понять что происходит на бекенде для конкретного user/feed/chat
- Проверить что возвращает API

## Workflow

1. **Извлечь ID из лога:**
   - `user_id` (UUID формат)
   - `feed_id` (UUID или числовой)
   - `chat_id` (UUID)
   - endpoint (путь типа `/feeds/123/posts`)
   - timestamp (для сужения поиска логов)

2. **Запустить сабагента:**

```
Task({
  subagent_type: "general-purpose",
  description: "Debug frontend issue",
  prompt: `
Исследуй проблему фронтенда.

**Контекст из лога:**
- user_id: ${user_id}
- feed_id: ${feed_id}
- endpoint: ${endpoint}
- время: ${timestamp}
- ошибка: ${error_message}

**Задачи:**

1. **Поиск логов в Loki** (используй Grafana MCP или curl):
   - Namespace: infatium-dev
   - Container: makefeed-api
   - Фильтр по user_id или feed_id
   - Время: ±15 минут от timestamp

2. **Проверка API** (если нужно):
   - Сгенерируй JWT для user_id
   - Сделай запрос к endpoint
   - Покажи что возвращает API

**Формат отчёта:**
- Что нашёл в логах (ошибки, warnings)
- Ответ API (если делал запрос)
- Вывод: в чём проблема
`
})
```

## Loki Query Reference

```bash
# Поиск по user_id
GRAFANA_TOKEN=$(cat ~/.claude/grafana-token)
curl -s -X POST 'https://grafana.infra.makekod.ru/api/ds/query' \
  -H "Authorization: Bearer $GRAFANA_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": {"uid": "P8E80F9AEF21F6940"},
      "expr": "{namespace=\"infatium-dev\", container=\"makefeed-api\"} |~ \"USER_ID\"",
      "queryType": "range",
      "maxLines": 100
    }],
    "from": "now-1h",
    "to": "now"
  }' | jq -r '.results.A.frames[0].data.values[2][]'
```

## API Request Reference

```bash
# Генерация JWT
JWT=$(KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl exec -n infatium-dev deployment/makefeed-api -- \
  python -c "
import sys
sys.path.insert(0, '/app/src')
from makefeed_api.utils.jwt import create_jwt_for_user
print(create_jwt_for_user('USER_ID'))
" 2>/dev/null)

# Запрос к API
curl -s "https://dev.service.infatium.ru/ENDPOINT" \
  -H "Authorization: Bearer $JWT" | jq .
```

## Примеры использования

**Пример 1: Фронт не видит посты**
```
/frontend-debug

Лог:
[FeedService] loadPosts failed for feed 123e4567-e89b-12d3-a456-426614174000
user: 447599e0-fc9e-4b7a-8576-d8e0ebc7755d
Error: 500 Internal Server Error
```

**Пример 2: Чат не работает**
```
/frontend-debug

ChatService error:
chat_id: abc-123-def
user_id: 447599e0-fc9e-4b7a-8576-d8e0ebc7755d
POST /chats/chat_message returned 422
```

## Известные user_id

| User | UUID |
|------|------|
| Slava | 447599e0-fc9e-4b7a-8576-d8e0ebc7755d |
| Demo | 5b684a49-6f14-484c-ba99-fd6fc8a54f90 |

## Endpoints

| Endpoint | Описание |
|----------|----------|
| GET /feeds | Список фидов |
| GET /feeds/{id} | Конкретный фид |
| GET /feeds/{id}/posts | Посты фида |
| GET /chats | Список чатов |
| POST /chats/chat_message | Отправка сообщения |
