package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	// Database
	DatabaseURL      string `envconfig:"DATABASE_URL" required:"true"`
	DatabasePoolMin  int    `envconfig:"DATABASE_POOL_MIN" default:"2"`
	DatabasePoolMax  int    `envconfig:"DATABASE_POOL_MAX" default:"15"`

	// NATS
	NATSUrl                   string `envconfig:"NATS_URL" default:"nats://nats:4222"`
	NATSConsumerEnabled       bool   `envconfig:"NATS_CONSUMER_ENABLED" default:"true"`
	NATSConsumerBatchSize     int    `envconfig:"NATS_CONSUMER_BATCH_SIZE" default:"10"`
	NATSConsumerAckWaitSec    int    `envconfig:"NATS_CONSUMER_ACK_WAIT_SECONDS" default:"60"`
	NATSConsumerMaxDeliver    int    `envconfig:"NATS_CONSUMER_MAX_DELIVER" default:"3"`
	NATSDigestConsumerEnabled bool   `envconfig:"NATS_DIGEST_CONSUMER_ENABLED" default:"false"`

	// AgentsClient
	AgentsClientTimeout       time.Duration `envconfig:"AGENTS_CLIENT_TIMEOUT" default:"60s"`
	AgentsClientMaxRetries    int           `envconfig:"AGENTS_CLIENT_MAX_RETRIES" default:"3"`
	AgentsClientRetryBaseDelay time.Duration `envconfig:"AGENTS_CLIENT_RETRY_BASE_DELAY" default:"1s"`

	// Processing
	ProcessingEnabled       bool          `envconfig:"PROCESSING_ENABLED" default:"true"`
	ProcessingDelaySeconds  float64       `envconfig:"PROCESSING_DELAY_SECONDS" default:"0.15"`
	LLMConcurrentRequests   int           `envconfig:"LLM_CONCURRENT_REQUESTS" default:"20"`
	LLMBatchSize            int           `envconfig:"LLM_BATCH_SIZE" default:"10"`
	LLMRequestTimeout       time.Duration `envconfig:"LLM_REQUEST_TIMEOUT" default:"30s"`
	DBConcurrentPostWrites  int           `envconfig:"DB_CONCURRENT_POST_WRITES" default:"5"`
	InitialSyncMaxRawPosts  int           `envconfig:"INITIAL_SYNC_MAX_RAW_POSTS" default:"15"`
	InitialSyncTargetPosts  int           `envconfig:"INITIAL_SYNC_TARGET_POSTS" default:"10"`

	// Observability
	OTELEnabled          bool   `envconfig:"OTEL_ENABLED" default:"true"`
	OTELServiceName      string `envconfig:"OTEL_SERVICE_NAME" default:"go-processor"`
	OTELExporterEndpoint string `envconfig:"OTEL_EXPORTER_ENDPOINT" default:"otel-collector:4317"`
	OTELEnvironment      string `envconfig:"OTEL_ENVIRONMENT" default:"development"`
	MetricsPort          int    `envconfig:"METRICS_PORT" default:"9464"`

	// GlitchTip (Sentry-compatible)
	GlitchTipDSN string `envconfig:"GLITCHTIP_DSN" default:""`
	Environment  string `envconfig:"ENVIRONMENT" default:"development"`

	// Redis
	RedisHost         string `envconfig:"REDIS_HOST"`
	RedisPort         int    `envconfig:"REDIS_PORT" default:"6379"`
	RedisPassword     string `envconfig:"REDIS_PASSWORD"`
	RedisDB           int    `envconfig:"REDIS_DB" default:"2"`
	ViewCacheTTLHours int    `envconfig:"VIEW_CACHE_TTL_HOURS" default:"72"`

	// Media Cache Warming
	MediaWarmingEnabled bool          `envconfig:"MEDIA_WARMING_ENABLED" default:"true"`
	MediaWarmingTimeout time.Duration `envconfig:"MEDIA_WARMING_TIMEOUT" default:"30s"`

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
