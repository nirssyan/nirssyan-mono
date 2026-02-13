package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	HTTPPort    int `envconfig:"HTTP_PORT" default:"8080"`
	MetricsPort int `envconfig:"METRICS_PORT" default:"9464"`
	Debug       bool

	DatabaseURL     string `envconfig:"DATABASE_URL" required:"true"`
	DatabasePoolMin int    `envconfig:"DATABASE_POOL_MIN" default:"5"`
	DatabasePoolMax int    `envconfig:"DATABASE_POOL_MAX" default:"20"`

	NATSURL string `envconfig:"NATS_URL" required:"true"`

	JWTSecret string `envconfig:"JWT_SECRET" required:"true"`

	TelegramBotToken        string `envconfig:"TELEGRAM_BOT_TOKEN"`
	TelegramBotURL          string `envconfig:"TELEGRAM_BOT_URL"`
	TelegramBotUsername     string `envconfig:"TELEGRAM_BOT_USERNAME"`
	TelegramLinkExpiryMins  int    `envconfig:"TELEGRAM_LINK_EXPIRY_MINS" default:"15"`

	FeedbackTelegramBotToken  string `envconfig:"FEEDBACK_TELEGRAM_BOT_TOKEN"`
	FeedbackTelegramChatID    string `envconfig:"FEEDBACK_TELEGRAM_CHAT_ID"`
	AdminTelegramFeedThreadID int    `envconfig:"ADMIN_TELEGRAM_FEED_THREAD_ID" default:"0"`
	AdminTelegramUserThreadID    int    `envconfig:"ADMIN_TELEGRAM_USER_THREAD_ID" default:"0"`
	FeedbackTelegramThreadID     int    `envconfig:"FEEDBACK_TELEGRAM_THREAD_ID" default:"0"`

	MediaProxyEnabled bool          `envconfig:"MEDIA_PROXY_ENABLED" default:"true"`
	MediaProxyTimeout time.Duration `envconfig:"MEDIA_PROXY_TIMEOUT" default:"30s"`

	S3Endpoint  string `envconfig:"S3_ENDPOINT" required:"true"`
	S3AccessKey string `envconfig:"S3_ACCESS_KEY" required:"true"`
	S3SecretKey string `envconfig:"S3_SECRET_KEY" required:"true"`
	S3PublicURL string `envconfig:"S3_PUBLIC_URL" required:"true"`
	S3UseSSL    bool   `envconfig:"S3_USE_SSL" default:"false"`
	S3Bucket    string `envconfig:"S3_BUCKET" default:"telegram-media"`

	OTELEnabled          bool   `envconfig:"OTEL_ENABLED" default:"false"`
	OTELServiceName      string `envconfig:"OTEL_SERVICE_NAME" default:"go-api"`
	OTELExporterEndpoint string `envconfig:"OTEL_EXPORTER_OTLP_ENDPOINT"`
	OTELEnvironment      string `envconfig:"OTEL_ENVIRONMENT" default:"development"`

	GlitchTipDSN string `envconfig:"GLITCHTIP_DSN"`
	Environment  string `envconfig:"ENVIRONMENT" default:"development"`

	AllowedOrigins []string `envconfig:"ALLOWED_ORIGINS" default:"*"`

	RuStoreKeyID          string `envconfig:"RUSTORE_KEY_ID"`
	RuStorePrivateKey     string `envconfig:"RUSTORE_PRIVATE_KEY"`
	RuStorePrivateKeyPath string `envconfig:"RUSTORE_PRIVATE_KEY_PATH"`

}

func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
