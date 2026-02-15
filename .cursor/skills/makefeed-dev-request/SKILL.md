---
name: makefeed-dev-request
description: Use when need to make HTTP requests to Makefeed/Infatium backend API in dev or prod environments - handles JWT auth via demo-login, supports all API endpoints
---

# Makefeed API Request Skill

Make authenticated HTTP requests to Makefeed/Infatium backend services.

## Environments

| Environment | Base URL | Notes |
|-------------|----------|-------|
| DEV | `https://dev.api.infatium.ru` | Development (self-signed cert, use `-sk`) |
| PROD | `https://api.infatium.ru` | Production |

## Authentication

### Demo Login (Go API)

```bash
JWT=$(curl -sk -X POST 'https://dev.api.infatium.ru/auth/demo-login' \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@infatium.ru","password":"QLjegxHXOWIczmpMoYk#D2RY7QhFv!j5"}' | jq -r '.access_token')
```

**Known users:**

| User | Email | UUID |
|------|-------|------|
| Slava (main) | `slava1kvartovkin@gmail.com` | `447599e0-fc9e-4b7a-8576-d8e0ebc7755d` |
| Demo | `demo@infatium.ru` | `5b684a49-6f14-484c-ba99-fd6fc8a54f90` |

## Quick Reference - Endpoints

### Public (no auth)
```bash
curl -sk 'https://dev.api.infatium.ru/healthz'
```

### Feeds
```bash
curl -sk 'https://dev.api.infatium.ru/feeds' \
  -H "Authorization: Bearer $JWT"

curl -sk 'https://dev.api.infatium.ru/feeds/{feed_id}' \
  -H "Authorization: Bearer $JWT"
```

### Tags
```bash
curl -sk 'https://dev.api.infatium.ru/tags' \
  -H "Authorization: Bearer $JWT"
```

### Subscriptions
```bash
curl -sk 'https://dev.api.infatium.ru/subscriptions/current' \
  -H "Authorization: Bearer $JWT"
```

### Sources
```bash
curl -sk -X POST 'https://dev.api.infatium.ru/sources/validate' \
  -H "Authorization: Bearer $JWT" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://t.me/channelname"}'
```

### Posts
```bash
curl -sk 'https://dev.api.infatium.ru/feeds/{feed_id}/posts?limit=10' \
  -H "Authorization: Bearer $JWT"
```

## Complete Example

```bash
# 1. Get JWT via demo login
JWT=$(curl -sk -X POST 'https://dev.api.infatium.ru/auth/demo-login' \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@infatium.ru","password":"QLjegxHXOWIczmpMoYk#D2RY7QhFv!j5"}' | jq -r '.access_token')

# 2. Make request
curl -sk 'https://dev.api.infatium.ru/feeds' \
  -H "Authorization: Bearer $JWT" | jq .
```

## Error Handling

| Status | Meaning | Action |
|--------|---------|--------|
| 401 | Unauthorized | Token expired, regenerate via demo-login |
| 403 | Forbidden | User doesn't have access to resource |
| 404 | Not Found | Check endpoint path or resource ID |
| 422 | Validation Error | Check request body format |
| 500 | Internal Server Error | Check Loki logs for details |
