package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	// Database
	DatabaseURL     string `envconfig:"DATABASE_URL" required:"true"`
	DatabasePoolMin int    `envconfig:"DATABASE_POOL_MIN" default:"2"`
	DatabasePoolMax int    `envconfig:"DATABASE_POOL_MAX" default:"5"`

	// OpenRouter API
	OpenRouterAPIKey string `envconfig:"OPENROUTER_API_KEY"`

	// Sync intervals
	LLMModelsSyncInterval    time.Duration `envconfig:"LLM_MODELS_SYNC_INTERVAL" default:"24h"`
	RegistrySyncInterval     time.Duration `envconfig:"REGISTRY_SYNC_INTERVAL" default:"24h"`
	LLMModelsSyncEnabled     bool          `envconfig:"LLM_MODELS_SYNC_ENABLED" default:"true"`
	RegistrySyncEnabled      bool          `envconfig:"REGISTRY_SYNC_ENABLED" default:"true"`

	// Telegram notifications
	TelegramBotToken string `envconfig:"TELEGRAM_BOT_TOKEN"`
	TelegramChatID   string `envconfig:"TELEGRAM_CHAT_ID" default:"-1002622491758"`
	TelegramThreadID int    `envconfig:"TELEGRAM_THREAD_ID" default:"1696"`

	// Observability
	OTELEnabled          bool   `envconfig:"OTEL_ENABLED" default:"true"`
	OTELServiceName      string `envconfig:"OTEL_SERVICE_NAME" default:"go-registry"`
	OTELExporterEndpoint string `envconfig:"OTEL_EXPORTER_ENDPOINT" default:"otel-collector:4317"`
	OTELEnvironment      string `envconfig:"OTEL_ENVIRONMENT" default:"development"`
	MetricsPort          int    `envconfig:"METRICS_PORT" default:"9464"`

	// GlitchTip (Sentry-compatible)
	GlitchTipDSN string `envconfig:"GLITCHTIP_DSN" default:""`
	Environment  string `envconfig:"ENVIRONMENT" default:"development"`

	// Server
	HTTPPort int  `envconfig:"HTTP_PORT" default:"8080"`
	Debug    bool `envconfig:"DEBUG" default:"false"`
}

func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
