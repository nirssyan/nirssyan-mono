package config

import (
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	DatabaseURL     string `envconfig:"DATABASE_URL" required:"true"`
	DatabasePoolMin int    `envconfig:"DATABASE_POOL_MIN" default:"2"`
	DatabasePoolMax int    `envconfig:"DATABASE_POOL_MAX" default:"10"`

	ScrapeInterval time.Duration `envconfig:"SCRAPE_INTERVAL" default:"30m"`
}

func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
