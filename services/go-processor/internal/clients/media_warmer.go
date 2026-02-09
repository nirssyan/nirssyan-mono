package clients

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type MediaWarmerClient struct {
	nc      *nats.Conn
	timeout time.Duration
}

func NewMediaWarmerClient(nc *nats.Conn, timeout time.Duration) *MediaWarmerClient {
	return &MediaWarmerClient{
		nc:      nc,
		timeout: timeout,
	}
}

type warmMediaItem struct {
	Type       string  `json:"type"`
	URL        string  `json:"url"`
	PreviewURL *string `json:"preview_url,omitempty"`
}

type warmMediaRequest struct {
	MediaObjects []warmMediaItem `json:"media_objects"`
}

type warmMediaResponse struct {
	Warmed  int    `json:"warmed"`
	Skipped int    `json:"skipped"`
	Failed  int    `json:"failed"`
	Error   string `json:"error,omitempty"`
}

func (c *MediaWarmerClient) WarmMedia(ctx context.Context, mediaObjects json.RawMessage) {
	if c == nil || c.nc == nil {
		return
	}

	var items []warmMediaItem
	if err := json.Unmarshal(mediaObjects, &items); err != nil {
		log.Debug().Err(err).Msg("Failed to unmarshal media objects for warming")
		return
	}

	// Filter: only warm Telegram media URLs
	var telegramItems []warmMediaItem
	for _, item := range items {
		if strings.Contains(item.URL, "/media/tg/") {
			telegramItems = append(telegramItems, item)
		}
	}

	if len(telegramItems) == 0 {
		return
	}

	req := warmMediaRequest{MediaObjects: telegramItems}
	reqData, err := json.Marshal(req)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to marshal warm media request")
		return
	}

	warmCtx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	msg, err := c.nc.RequestWithContext(warmCtx, "telegram.media.warm", reqData)
	if err != nil {
		log.Warn().Err(err).Int("items", len(telegramItems)).Msg("Media warming NATS request failed")
		return
	}

	var resp warmMediaResponse
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		log.Warn().Err(err).Msg("Failed to unmarshal warm media response")
		return
	}

	log.Info().
		Int("warmed", resp.Warmed).
		Int("skipped", resp.Skipped).
		Int("failed", resp.Failed).
		Msg("Media warming via NATS completed")
}
