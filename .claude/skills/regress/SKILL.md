---
name: regress
description: Регрессионное тестирование Makefeed/Infatium API. Запускай когда пользователь говорит "regress", "регресс", "протестируй стенд", "проверь API". Создает тестовую ленту, проверяет AI-генерацию постов, удаляет ленту.
argument-hint: [dev|prod]
---

# Regress - Regression Testing via pytest

Запускает pytest тесты для Makefeed/Infatium API. Создаёт ровно 2 ленты (1 SINGLE_POST + 1 DIGEST) и переиспользует их во всех тестах.

## Setup (one-time)

```bash
python3 -m pip install pytest pytest-xdist httpx PyJWT websockets
```

## Run

```bash
cd $SKILL_DIR && python3 -m pytest --tb=short -q --env ${1:-dev}
```

Аргумент `--env` принимает `dev` (default) или `prod`.

## Report

Из вывода pytest сформируй таблицу:

```markdown
## Regress Test Results - {env}

| Test | Status | Details |
|------|--------|---------|
| ... | PASS/FAIL | ... |

**Overall: X passed, Y failed** in Zs
```

**ВАЖНО:** Отчёт — это ЕДИНСТВЕННЫЙ вывод. Не выводи raw JSON, логи или промежуточные данные.

## What's tested

| File | Tests |
|------|-------|
| test_suggestions.py | Views & Telegram sources available |
| test_polling.py | Poller cycles active, processor errors < 5 |
| test_feed_single.py | SINGLE_POST: create → posts appear < 45s → titles, views, sources → summarize_unseen → digest post created, posts marked read |
| test_feed_digest.py | DIGEST: create → digest appears < 90s → has title & views |
| test_media_proxy.py | Media URLs return 200, cache works |
| test_auth.py | Email/password login, token validation, refresh rotation, logout |
| test_feedback.py | Feedback endpoint, error log counts, GlitchTip reachable |
| test_websocket.py | WS: connect, receive events (reuses single_feed) |

## Telegram Report

Telegram-отчёт отправляется автоматически в топик regress. `--no-tg-report` для отключения.

## Troubleshooting

- **JWT errors**: проверь SUPABASE_JWT_SECRET в k8s secret `service-secrets`
- **Feed limit (403)**: pre_cleanup fixture удаляет orphaned users_feeds автоматически
- **Processing timeout**: логи worker-processor-go
- **Media 404**: go-poller file_handler, MTProto авторизация
