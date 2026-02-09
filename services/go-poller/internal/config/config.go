package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	// Feature flags
	RSSPollingEnabled  bool `envconfig:"RSS_POLLING_ENABLED" default:"true"`
	WebPollingEnabled  bool `envconfig:"WEB_POLLING_ENABLED" default:"true"`

	// Database
	DatabaseURL      string `envconfig:"DATABASE_URL" required:"true"`
	DatabasePoolMin  int    `envconfig:"DATABASE_POOL_MIN" default:"2"`
	DatabasePoolMax  int    `envconfig:"DATABASE_POOL_MAX" default:"10"`

	// NATS
	NATSUrl                       string `envconfig:"NATS_URL" default:"nats://localhost:4222"`
	NATSPublishEnabled            bool   `envconfig:"NATS_PUBLISH_ENABLED" default:"true"`
	NATSValidationHandlerEnabled  bool   `envconfig:"NATS_VALIDATION_HANDLER_ENABLED" default:"true"`

	// Moderation
	ModerationServiceURL string `envconfig:"MODERATION_SERVICE_URL" default:"http://makefeed-api:8000"`

	// RSS Settings
	RSSPollingIntervalSeconds int           `envconfig:"RSS_POLLING_INTERVAL_SECONDS" default:"300"`
	RSSConcurrentFeeds        int           `envconfig:"RSS_CONCURRENT_FEEDS" default:"5"`
	RSSFeedTimeout            time.Duration `envconfig:"RSS_FEED_TIMEOUT" default:"7m"`
	RSSTimeout                time.Duration `envconfig:"RSS_TIMEOUT" default:"30s"`
	RSSMaxRetries             int           `envconfig:"RSS_MAX_RETRIES" default:"3"`
	RSSFetchFullContent       bool          `envconfig:"RSS_FETCH_FULL_CONTENT" default:"true"`
	RSSMinContentLength       int           `envconfig:"RSS_MIN_CONTENT_LENGTH" default:"500"`
	RSSInitialArticlesCount   int           `envconfig:"RSS_INITIAL_ARTICLES_COUNT" default:"5"`
	RSSMaxArticlesPerRequest  int           `envconfig:"RSS_MAX_ARTICLES_PER_REQUEST" default:"20"`

	// RSS Tier intervals (seconds)
	RSSTierHotInterval        int `envconfig:"RSS_TIER_HOT_INTERVAL" default:"300"`
	RSSTierWarmInterval       int `envconfig:"RSS_TIER_WARM_INTERVAL" default:"600"`
	RSSTierColdInterval       int `envconfig:"RSS_TIER_COLD_INTERVAL" default:"3600"`
	RSSTierQuarantineInterval int `envconfig:"RSS_TIER_QUARANTINE_INTERVAL" default:"14400"`

	// Web Settings
	WebPollingIntervalSeconds int           `envconfig:"WEB_POLLING_INTERVAL_SECONDS" default:"600"`
	WebConcurrentRequests     int           `envconfig:"WEB_CONCURRENT_REQUESTS" default:"3"`
	WebFeedTimeout            time.Duration `envconfig:"WEB_FEED_TIMEOUT" default:"10m"`
	WebInitialArticlesCount   int           `envconfig:"WEB_INITIAL_ARTICLES_COUNT" default:"5"`
	WebMaxArticlesPerRequest  int           `envconfig:"WEB_MAX_ARTICLES_PER_REQUEST" default:"10"`

	// Web Tier intervals (seconds)
	WebTierHotInterval        int `envconfig:"WEB_TIER_HOT_INTERVAL" default:"600"`
	WebTierWarmInterval       int `envconfig:"WEB_TIER_WARM_INTERVAL" default:"1800"`
	WebTierColdInterval       int `envconfig:"WEB_TIER_COLD_INTERVAL" default:"7200"`
	WebTierQuarantineInterval int `envconfig:"WEB_TIER_QUARANTINE_INTERVAL" default:"28800"`

	// Scraping/HTTP Settings
	ScrapingRequestsPerSec float64       `envconfig:"SCRAPING_REQUESTS_PER_SEC" default:"0.5"`
	ScrapingTimeout        time.Duration `envconfig:"SCRAPING_TIMEOUT" default:"10s"`
	ScrapingMaxRetries     int           `envconfig:"SCRAPING_MAX_RETRIES" default:"3"`
	HTTPCacheEnabled       bool          `envconfig:"HTTP_CACHE_ENABLED" default:"true"`
	HTTPCacheTTLHours      int           `envconfig:"HTTP_CACHE_TTL_HOURS" default:"24"`

	// Observability
	OTELEnabled             bool   `envconfig:"OTEL_ENABLED" default:"true"`
	OTELServiceName         string `envconfig:"OTEL_SERVICE_NAME" default:"makefeed-go-poller"`
	OTELExporterEndpoint    string `envconfig:"OTEL_EXPORTER_ENDPOINT" default:"localhost:4317"`
	OTELEnvironment         string `envconfig:"OTEL_ENVIRONMENT" default:"development"`
	MetricsPort             int    `envconfig:"METRICS_PORT" default:"9464"`

	// Telegram Feature Flag
	TelegramPollingEnabled bool `envconfig:"TELEGRAM_POLLING_ENABLED" default:"false"`

	// Telegram API (MTProto)
	TelegramAPIID   int    `envconfig:"TELEGRAM_API_ID"`
	TelegramAPIHash string `envconfig:"TELEGRAM_API_HASH"`
	TelegramPhone   string `envconfig:"TELEGRAM_PHONE"`

	// Telegram Session
	TelegramWorkdir     string `envconfig:"TELEGRAM_WORKDIR" default:"/app/.telegram/"`
	TelegramSessionName string `envconfig:"TELEGRAM_SESSION_NAME" default:"go_session"`

	// Telegram Polling
	TelegramPollingIntervalSeconds int `envconfig:"TELEGRAM_POLLING_INTERVAL_SECONDS" default:"5"`
	TelegramConcurrentChannels     int `envconfig:"TELEGRAM_CONCURRENT_CHANNELS" default:"3"`
	TelegramMaxMessagesPerRequest  int `envconfig:"TELEGRAM_MAX_MESSAGES_PER_REQUEST" default:"100"`
	TelegramInitialMessagesCount   int `envconfig:"TELEGRAM_INITIAL_MESSAGES_COUNT" default:"25"`

	// Telegram Tier intervals (seconds) - more aggressive than RSS/Web
	TelegramTierHotInterval        int `envconfig:"TELEGRAM_TIER_HOT_INTERVAL" default:"30"`
	TelegramTierWarmInterval       int `envconfig:"TELEGRAM_TIER_WARM_INTERVAL" default:"120"`
	TelegramTierColdInterval       int `envconfig:"TELEGRAM_TIER_COLD_INTERVAL" default:"600"`
	TelegramTierQuarantineInterval int `envconfig:"TELEGRAM_TIER_QUARANTINE_INTERVAL" default:"3600"`

	// Telegram Rate Limiting
	TelegramFloodWaitCooldownSeconds  int     `envconfig:"TELEGRAM_FLOOD_WAIT_COOLDOWN_SECONDS" default:"300"`
	TelegramAdaptiveRateEnabled       bool    `envconfig:"TELEGRAM_ADAPTIVE_RATE_ENABLED" default:"true"`
	TelegramAdaptiveRateMaxMultiplier float64 `envconfig:"TELEGRAM_ADAPTIVE_RATE_MAX_MULTIPLIER" default:"3.0"`
	TelegramBaseRequestDelayMs        int     `envconfig:"TELEGRAM_BASE_REQUEST_DELAY_MS" default:"100"`

	// Telegram Media
	TelegramMediaBaseURL string `envconfig:"TELEGRAM_MEDIA_BASE_URL" default:"http://localhost:8000"`

	// S3/MinIO (media cache warming)
	S3Endpoint  string `envconfig:"S3_ENDPOINT"`
	S3AccessKey string `envconfig:"S3_ACCESS_KEY"`
	S3SecretKey string `envconfig:"S3_SECRET_KEY"`
	S3UseSSL    bool   `envconfig:"S3_USE_SSL" default:"false"`
	S3Bucket    string `envconfig:"S3_BUCKET" default:"telegram-media"`

	// Media Cache Warming
	MediaWarmingEnabled     bool          `envconfig:"MEDIA_WARMING_ENABLED" default:"true"`
	MediaWarmingRatePerSec  float64       `envconfig:"MEDIA_WARMING_RATE_PER_SEC" default:"5"`
	MediaWarmingConcurrency int           `envconfig:"MEDIA_WARMING_CONCURRENCY" default:"3"`
	MediaWarmingTimeout     time.Duration `envconfig:"MEDIA_WARMING_TIMEOUT" default:"30s"`

	// Error Tracking
	GlitchTipDSN string `envconfig:"GLITCHTIP_DSN"`
	Environment  string `envconfig:"ENVIRONMENT" default:"development"`

	// Server
	HTTPPort int  `envconfig:"HTTP_PORT" default:"8080"`
	Debug    bool `envconfig:"DEBUG" default:"false"`
}

func (c *Config) RSSTierIntervals() map[string]int {
	return map[string]int{
		"HOT":        c.RSSTierHotInterval,
		"WARM":       c.RSSTierWarmInterval,
		"COLD":       c.RSSTierColdInterval,
		"QUARANTINE": c.RSSTierQuarantineInterval,
	}
}

func (c *Config) WebTierIntervals() map[string]int {
	return map[string]int{
		"HOT":        c.WebTierHotInterval,
		"WARM":       c.WebTierWarmInterval,
		"COLD":       c.WebTierColdInterval,
		"QUARANTINE": c.WebTierQuarantineInterval,
	}
}

func (c *Config) TelegramTierIntervals() map[string]int {
	return map[string]int{
		"HOT":        c.TelegramTierHotInterval,
		"WARM":       c.TelegramTierWarmInterval,
		"COLD":       c.TelegramTierColdInterval,
		"QUARANTINE": c.TelegramTierQuarantineInterval,
	}
}

func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
