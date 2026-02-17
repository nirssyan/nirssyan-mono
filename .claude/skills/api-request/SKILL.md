---
name: api-request
description: Use when need to make HTTP requests to Makefeed/Infatium backend API in dev or prod environments - handles JWT auth via local signing, supports all API endpoints
---

# Makefeed API Request Skill

Make authenticated HTTP requests to Makefeed/Infatium backend services.

## Environment Setup

Set environment at the top, everything else derives from it:

```bash
ENV=dev  # or prod

# Derived
if [ "$ENV" = "prod" ]; then
  NS=infatium-prod
  BASE_URL=https://api.infatium.ru
else
  NS=infatium-dev
  BASE_URL=https://dev.api.infatium.ru
fi
```

| Environment | Namespace | Base URL |
|-------------|-----------|----------|
| DEV | `infatium-dev` | `https://dev.api.infatium.ru` |
| PROD | `infatium-prod` | `https://api.infatium.ru` |

## Authentication — Local JWT Generation

Fetch `JWT_SECRET` from k8s and sign JWT locally with PyJWT (no kubectl exec into pods):

```bash
# 1. Get JWT_SECRET from k8s
JWT_SECRET=$(KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get secret auth-secrets -n $NS \
  -o jsonpath='{.data.JWT_SECRET}' | base64 -d)

# Fallback to service-secrets if auth-secrets doesn't have it
if [ -z "$JWT_SECRET" ]; then
  JWT_SECRET=$(KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get secret service-secrets -n $NS \
    -o jsonpath='{.data.SUPABASE_JWT_SECRET}' | base64 -d)
fi

# 2. Sign JWT locally
USER_ID="447599e0-fc9e-4b7a-8576-d8e0ebc7755d"

JWT=$(python3 -c "
import jwt, time, uuid
now = int(time.time())
print(jwt.encode({
    'iss': 'auth-service',
    'sub': '$USER_ID',
    'uid': '$USER_ID',
    'aud': ['makefeed-api'],
    'email': 'slava1kvartovkin@gmail.com',
    'iat': now,
    'exp': now + 3600,
    'jti': f'skill-{now}'
}, '$JWT_SECRET', algorithm='HS256'))
")
```

Requires `pip install PyJWT`.

**Known users:**

| User | Email | UUID |
|------|-------|------|
| Slava (main) | `slava1kvartovkin@gmail.com` | `447599e0-fc9e-4b7a-8576-d8e0ebc7755d` |
| Demo | `demo@infatium.ru` | `5b684a49-6f14-484c-ba99-fd6fc8a54f90` |

**Note:** Demo user can also auth via `POST /auth/demo-login` with `{"email":"demo@infatium.ru","password":"demo123"}` when `DEMO_MODE_ENABLED=true`.

## Quick Reference — Endpoints

### Public (no auth)
```bash
curl -sk "$BASE_URL/healthz"
```

### Feeds
```bash
# List feeds
curl -sk "$BASE_URL/feeds" -H "Authorization: Bearer $JWT"

# Get feed by ID
curl -sk "$BASE_URL/feeds/{feed_id}" -H "Authorization: Bearer $JWT"
```

### Subscriptions
```bash
curl -sk "$BASE_URL/subscriptions/current" -H "Authorization: Bearer $JWT"
```

### Sources
```bash
curl -sk -X POST "$BASE_URL/sources/validate" \
  -H "Authorization: Bearer $JWT" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://t.me/channelname"}'
```

### Posts
```bash
curl -sk "$BASE_URL/feeds/{feed_id}/posts?limit=10" -H "Authorization: Bearer $JWT"
```

## Complete Example (Slava's Account, DEV)

```bash
ENV=dev
NS=infatium-dev
BASE_URL=https://dev.api.infatium.ru

JWT_SECRET=$(KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig kubectl get secret auth-secrets -n $NS \
  -o jsonpath='{.data.JWT_SECRET}' | base64 -d)

JWT=$(python3 -c "
import jwt, time
now = int(time.time())
print(jwt.encode({
    'iss': 'auth-service',
    'sub': '447599e0-fc9e-4b7a-8576-d8e0ebc7755d',
    'uid': '447599e0-fc9e-4b7a-8576-d8e0ebc7755d',
    'aud': ['makefeed-api'],
    'email': 'slava1kvartovkin@gmail.com',
    'iat': now, 'exp': now + 3600,
    'jti': f'skill-{now}'
}, '$JWT_SECRET', algorithm='HS256'))
")

curl -sk "$BASE_URL/feeds" -H "Authorization: Bearer $JWT" | jq .
```

## Error Handling

| Status | Meaning | Action |
|--------|---------|--------|
| 401 | Unauthorized | Token expired or invalid secret — regenerate JWT |
| 403 | Forbidden | User doesn't have access to resource |
| 404 | Not Found | Check endpoint path or resource ID |
| 422 | Validation Error | Check request body format |
