package config

import (
	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	// Server
	Host  string `envconfig:"HOST" default:"0.0.0.0"`
	Port  int    `envconfig:"PORT" default:"8000"`
	Debug bool   `envconfig:"DEBUG" default:"false"`

	// App Store Connect Webhooks
	AppStoreWebhookSecret    string `envconfig:"APPSTORE_WEBHOOK_SECRET"`
	AppStoreTelegramBotToken string `envconfig:"APPSTORE_TELEGRAM_BOT_TOKEN"`
	AppStoreTelegramChatID   string `envconfig:"APPSTORE_TELEGRAM_CHAT_ID"`
	AppStoreTelegramThreadID int    `envconfig:"APPSTORE_TELEGRAM_THREAD_ID"`

	// Sentry/GlitchTip Webhooks
	SentryTelegramBotToken string `envconfig:"SENTRY_WEBHOOK_TELEGRAM_BOT_TOKEN"`
	SentryTelegramChatID   string `envconfig:"SENTRY_WEBHOOK_TELEGRAM_CHAT_ID"`
	SentryTelegramThreadID int    `envconfig:"SENTRY_WEBHOOK_TELEGRAM_THREAD_ID"`

	// Error Tracking
	GlitchTipDSN string `envconfig:"GLITCHTIP_DSN"`
	Environment  string `envconfig:"ENVIRONMENT" default:"production"`

	// OpenTelemetry
	OTelEnabled          bool   `envconfig:"OTEL_ENABLED" default:"true"`
	OTelServiceName      string `envconfig:"OTEL_SERVICE_NAME" default:"makefeed-integrations"`
	OTelExporterEndpoint string `envconfig:"OTEL_EXPORTER_ENDPOINT" default:"tempo.infrastructure.svc.cluster.local:4317"`
	OTelEnvironment      string `envconfig:"OTEL_ENVIRONMENT" default:"production"`

	// Prometheus Metrics
	MetricsPort int `envconfig:"METRICS_PORT" default:"9464"`
}

func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
