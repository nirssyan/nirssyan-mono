package clients

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
)

type ValidationClient struct {
	nc       *nats.Conn
	cache    *redis.Client
	cacheTTL time.Duration
}

func NewValidationClient(nc *nats.Conn, redisClient *redis.Client, cacheTTL time.Duration) *ValidationClient {
	return &ValidationClient{
		nc:       nc,
		cache:    redisClient,
		cacheTTL: cacheTTL,
	}
}

type ValidateSourceRequest struct {
	URL         string `json:"url"`
	SourceType  string `json:"source_type"`
	Lightweight bool   `json:"lightweight"`
}

type ValidateSourceResult struct {
	Valid           bool    `json:"valid"`
	Title           *string `json:"title,omitempty"`
	Description     *string `json:"description,omitempty"`
	Error           *string `json:"error,omitempty"`
	Message         *string `json:"message,omitempty"`
	SourceType      *string `json:"source_type,omitempty"`
	DetectedFeedURL *string `json:"detected_feed_url,omitempty"`
}

func (c *ValidationClient) cacheKey(sourceType, url string) string {
	return fmt.Sprintf("source_validate:%s:%s", strings.ToLower(sourceType), strings.ToLower(url))
}

func (c *ValidationClient) ValidateSource(ctx context.Context, url, sourceType string, lightweight bool) (*ValidateSourceResult, error) {
	key := c.cacheKey(sourceType, url)

	if c.cache != nil {
		cached, err := c.cache.Get(ctx, key).Bytes()
		if err == nil {
			var result ValidateSourceResult
			if err := json.Unmarshal(cached, &result); err == nil {
				log.Debug().Str("url", url).Msg("Source validation cache hit")
				return &result, nil
			}
		} else if err != redis.Nil {
			log.Warn().Err(err).Str("key", key).Msg("Redis cache read error")
		}
	}

	// Try NATS validation with short timeout, fallback to simple validation
	var result *ValidateSourceResult
	if c.nc != nil {
		timeoutCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		defer cancel()

		req := ValidateSourceRequest{
			URL:         url,
			SourceType:  sourceType,
			Lightweight: lightweight,
		}

		data, err := json.Marshal(req)
		if err == nil {
			msg, err := c.nc.RequestWithContext(timeoutCtx, "validation.validate_source", data)
			if err == nil {
				var resp ValidateSourceResult
				if err := json.Unmarshal(msg.Data, &resp); err == nil {
					if resp.Valid && resp.SourceType == nil {
						fallback, _ := c.validateSimple(url, sourceType)
						resp.SourceType = fallback.SourceType
					}
					result = &resp
				}
			} else {
				log.Debug().Err(err).Str("url", url).Msg("NATS validation failed, using fallback")
			}
		}
	}

	if result == nil {
		var err error
		result, err = c.validateSimple(url, sourceType)
		if err != nil {
			return nil, err
		}
	}

	if c.cache != nil && result.Valid {
		data, err := json.Marshal(result)
		if err == nil {
			if err := c.cache.Set(ctx, key, data, c.cacheTTL).Err(); err != nil {
				log.Warn().Err(err).Str("key", key).Msg("Redis cache write error")
			}
		}
	}

	return result, nil
}

var telegramUsernameRegex = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_]{3,30}$`)

func (c *ValidationClient) validateSimple(url, sourceType string) (*ValidateSourceResult, error) {
	url = strings.TrimSpace(url)

	if strings.Contains(strings.ToLower(url), "t.me/") || strings.Contains(strings.ToLower(url), "telegram.me/") {
		username := extractTelegramUsername(url)
		if username != "" && telegramUsernameRegex.MatchString(username) {
			st := "TELEGRAM"
			return &ValidateSourceResult{
				Valid:      true,
				SourceType: &st,
			}, nil
		}
		msg := "invalid telegram username format"
		return &ValidateSourceResult{Valid: false, Message: &msg}, nil
	}

	if strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://") {
		st := strings.ToUpper(sourceType)
		if st == "" {
			st = "WEBSITE"
		}
		return &ValidateSourceResult{
			Valid:      true,
			SourceType: &st,
		}, nil
	}

	msg := "unsupported source format"
	return &ValidateSourceResult{Valid: false, Message: &msg}, nil
}

func extractTelegramUsername(url string) string {
	url = strings.ToLower(url)
	if idx := strings.Index(url, "t.me/"); idx != -1 {
		username := url[idx+5:]
		if slashIdx := strings.Index(username, "/"); slashIdx != -1 {
			username = username[:slashIdx]
		}
		if qIdx := strings.Index(username, "?"); qIdx != -1 {
			username = username[:qIdx]
		}
		return username
	}
	if idx := strings.Index(url, "telegram.me/"); idx != -1 {
		username := url[idx+12:]
		if slashIdx := strings.Index(username, "/"); slashIdx != -1 {
			username = username[:slashIdx]
		}
		if qIdx := strings.Index(username, "?"); qIdx != -1 {
			username = username[:qIdx]
		}
		return username
	}
	return ""
}
