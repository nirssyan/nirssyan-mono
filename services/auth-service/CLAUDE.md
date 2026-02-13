# CLAUDE.md

Authentication microservice for Infatium/Makefeed platform.

## Overview

Go microservice providing:
- Google/Apple OAuth (native SDK tokens)
- Magic Link (passwordless email)
- Refresh Token Rotation with reuse detection (RFC 9700)

## Quick Start

```bash
# Development
go mod download
go run ./cmd/server

# Build
go build -o auth-service ./cmd/server

# Docker
docker build -t auth-service .
```

## Project Structure

```
auth-service/
├── cmd/server/main.go       # Entry point, chi router setup
├── internal/
│   ├── config/config.go     # Environment config
│   ├── handler/
│   │   ├── auth.go          # HTTP handlers for /auth/*
│   │   └── health.go        # /healthz, /readyz
│   ├── service/
│   │   ├── auth.go          # Business logic
│   │   ├── jwt.go           # JWT generation/validation
│   │   ├── password.go      # Argon2id hashing
│   │   ├── google.go        # Google ID token validation
│   │   ├── apple.go         # Apple ID token validation
│   │   └── email.go         # Magic link emails (Resend)
│   ├── repository/
│   │   ├── user.go          # Users CRUD
│   │   ├── refresh_token.go # Refresh tokens CRUD
│   │   ├── token_family.go  # Token families CRUD
│   │   └── magic_link.go    # Magic link tokens CRUD
│   ├── middleware/
│   │   └── rate_limit.go    # Per-endpoint rate limiting
│   └── model/models.go      # Domain models
└── migrations/              # SQL migrations
```

## API Endpoints

| Method | Endpoint | Description | Rate Limit |
|--------|----------|-------------|------------|
| POST | `/auth/login` | Email/password → JWT | 10/min |
| POST | `/auth/google` | Google ID token → JWT | 10/min |
| POST | `/auth/apple` | Apple ID token → JWT | 10/min |
| POST | `/auth/magic-link` | Send magic link email | 3/min |
| POST | `/auth/verify` | Verify magic link → JWT | 10/min |
| POST | `/auth/refresh` | Refresh token → new JWT pair | 20/min |
| POST | `/auth/logout` | Revoke refresh token family | 10/min |
| GET | `/healthz` | Liveness probe | — |
| GET | `/readyz` | Readiness probe | — |

## Environment Variables

```bash
# Required
DATABASE_URL="postgres://user:pass@host:5432/db"
JWT_SECRET="64+ chars cryptographically random"

# OAuth - Google
GOOGLE_CLIENT_ID="xxx.apps.googleusercontent.com"

# OAuth - Apple
APPLE_TEAM_ID="WJL5673TCJ"
APPLE_KEY_ID="9D5VSP8QJV"
APPLE_CLIENT_ID="com.nirssyan.makefeed"

# Email (Resend)
RESEND_API_KEY="re_xxx"
EMAIL_FROM="noreply@infatium.ru"

# Optional
ACCESS_TOKEN_TTL="15m"      # default
REFRESH_TOKEN_TTL="336h"    # 14 days, default
MAGIC_LINK_TTL="15m"        # default
LOG_LEVEL="info"
SERVER_ADDR=":8080"         # default
```

## Security Features

- **JWT**: HS256 signed, 15 min expiry
- **Password**: Argon2id (64 MiB, 3 iter, 4 parallel)
- **Refresh Tokens**: Rotation with reuse detection → family revocation
- **Magic Links**: Single-use, 15 min expiry, SHA-256 hashed
- **Rate Limiting**: Per-endpoint, IP-based

## JWT Claims

```json
{
  "iss": "auth-service",
  "sub": "user-uuid",
  "aud": ["makefeed-api"],
  "exp": 1234567890,
  "iat": 1234567890,
  "jti": "token-uuid",
  "uid": "user-uuid",
  "email": "user@example.com"
}
```

## Database Schema

New tables:
- `refresh_tokens` - Refresh tokens with rotation tracking
- `token_families` - Token rotation chains
- `magic_link_tokens` - Magic link tokens

Modified tables:
- `users` - Added: `provider`, `provider_id`, `password_hash`, `email_verified_at`

## Integration with go-api

Both services share `JWT_SECRET` for token validation:
- auth-service: Issues tokens
- go-api: Validates tokens (existing middleware)

## Deployment

K8s manifests in `infra-startup/projects/infatium/base/auth-service/`

```bash
# Deploy to dev
cd infra-startup && ./deploy -p infatium -e dev
```

## Testing

```bash
# Unit tests
go test ./...

# Integration tests (requires DB)
DATABASE_URL="..." go test ./... -tags=integration
```
