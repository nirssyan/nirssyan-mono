package clients

import (
	"context"
	"encoding/json"
	"regexp"
	"strings"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type ValidationClient struct {
	nc *nats.Conn
}

func NewValidationClient(nc *nats.Conn) *ValidationClient {
	return &ValidationClient{nc: nc}
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

func (c *ValidationClient) ValidateSource(ctx context.Context, url, sourceType string, lightweight bool) (*ValidateSourceResult, error) {
	// Try NATS validation with short timeout, fallback to simple validation
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
					// If NATS returned valid but no source type, use fallback to determine type
					if resp.Valid && resp.SourceType == nil {
						fallback, _ := c.validateSimple(url, sourceType)
						resp.SourceType = fallback.SourceType
					}
					return &resp, nil
				}
			}
			log.Debug().Err(err).Str("url", url).Msg("NATS validation failed, using fallback")
		}
	}

	// Fallback: simple format-based validation
	return c.validateSimple(url, sourceType)
}

var telegramUsernameRegex = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_]{3,30}$`)

func (c *ValidationClient) validateSimple(url, sourceType string) (*ValidateSourceResult, error) {
	url = strings.TrimSpace(url)

	// Telegram validation
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

	// Website validation - just check it looks like a URL
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
