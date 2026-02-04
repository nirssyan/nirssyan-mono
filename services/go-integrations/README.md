# integrations-go

Go-based webhook integration service for handling App Store, Sentry, and GlitchTip notifications.

## Features

- App Store Server Notifications (HMAC-SHA256 verification)
- Sentry webhook notifications
- GlitchTip Slack-compatible webhooks
- Telegram message delivery
- OpenTelemetry tracing (OTLP to Tempo)
- Prometheus metrics on port 9464

## Development

```bash
# Run locally
go run ./cmd/integrations

# Build
go build -o integrations ./cmd/integrations

# Test
go test -v -race ./...
```

## Environment Variables

See `.env.example` for required configuration.

## Endpoints

- `GET /healthz` - Health check
- `POST /webhooks/appstore/notifications` - App Store webhooks
- `POST /webhooks/sentry/notifications` - Sentry webhooks
- `POST /webhooks/glitchtip/notifications` - GlitchTip webhooks

## Docker

```bash
docker build -t makefeed-integrations-go .
docker run -p 8000:8000 -p 9464:9464 --env-file .env makefeed-integrations-go
```
