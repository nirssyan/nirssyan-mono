package config

import (
	"os"
	"time"
)

type Config struct {
	DatabaseURL string
	JWTSecret   []byte
	ServerAddr  string

	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
	MagicLinkTTL    time.Duration

	GoogleClientID string

	AppleTeamID   string
	AppleKeyID    string
	AppleClientID string

	ResendAPIKey string
	EmailFrom    string

	LogLevel string
}

func Load() (*Config, error) {
	cfg := &Config{
		DatabaseURL: getEnv("DATABASE_URL", ""),
		JWTSecret:   []byte(getEnv("JWT_SECRET", "")),
		ServerAddr:  getEnv("SERVER_ADDR", ":8080"),

		AccessTokenTTL:  parseDuration(getEnv("ACCESS_TOKEN_TTL", "15m"), 15*time.Minute),
		RefreshTokenTTL: parseDuration(getEnv("REFRESH_TOKEN_TTL", "336h"), 336*time.Hour),
		MagicLinkTTL:    parseDuration(getEnv("MAGIC_LINK_TTL", "15m"), 15*time.Minute),

		GoogleClientID: getEnv("GOOGLE_CLIENT_ID", ""),

		AppleTeamID:   getEnv("APPLE_TEAM_ID", ""),
		AppleKeyID:    getEnv("APPLE_KEY_ID", ""),
		AppleClientID: getEnv("APPLE_CLIENT_ID", ""),

		ResendAPIKey: getEnv("RESEND_API_KEY", ""),
		EmailFrom:    getEnv("EMAIL_FROM", "noreply@infatium.ru"),

		LogLevel: getEnv("LOG_LEVEL", "info"),
	}

	return cfg, nil
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func parseDuration(val string, defaultVal time.Duration) time.Duration {
	d, err := time.ParseDuration(val)
	if err != nil {
		return defaultVal
	}
	return d
}
