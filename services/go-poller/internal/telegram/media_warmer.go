package telegram

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"
	natsgo "github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
	"golang.org/x/time/rate"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/storage"
)

const (
	MediaWarmSubject = "telegram.media.warm"
	MediaWarmQueue   = "telegram-media-warm"
)

type MediaWarmer struct {
	cfg      *config.Config
	client   *Client
	s3Client *storage.S3Client
	bucket   string
	limiter  *rate.Limiter
	dbPool   *pgxpool.Pool
}

type WarmMediaRequest struct {
	MediaObjects []WarmMediaItem `json:"media_objects"`
}

type WarmMediaItem struct {
	Type       string  `json:"type"`
	URL        string  `json:"url"`
	PreviewURL *string `json:"preview_url,omitempty"`
}

type WarmMediaResponse struct {
	Warmed  int    `json:"warmed"`
	Skipped int    `json:"skipped"`
	Failed  int    `json:"failed"`
	Error   string `json:"error,omitempty"`
}

func NewMediaWarmer(cfg *config.Config, client *Client, s3Client *storage.S3Client, dbPool *pgxpool.Pool) *MediaWarmer {
	return &MediaWarmer{
		cfg:      cfg,
		client:   client,
		s3Client: s3Client,
		bucket:   cfg.S3Bucket,
		limiter:  rate.NewLimiter(rate.Limit(cfg.MediaWarmingRatePerSec), 1),
		dbPool:   dbPool,
	}
}

func (w *MediaWarmer) Register(nc *natsgo.Conn) error {
	_, err := nc.QueueSubscribe(MediaWarmSubject, MediaWarmQueue, w.handleWarmRequest)
	if err != nil {
		return err
	}

	log.Info().
		Str("subject", MediaWarmSubject).
		Str("queue", MediaWarmQueue).
		Msg("Registered media warm handler")

	return nil
}

func (w *MediaWarmer) handleWarmRequest(msg *natsgo.Msg) {
	var req WarmMediaRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		log.Error().Err(err).Msg("Failed to unmarshal warm request")
		resp, _ := json.Marshal(WarmMediaResponse{Error: "invalid request"})
		msg.Respond(resp)
		return
	}

	ctx := context.Background()
	if w.cfg.MediaWarmingTimeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, w.cfg.MediaWarmingTimeout)
		defer cancel()
	}

	result := w.WarmMediaObjects(ctx, req.MediaObjects)

	log.Info().
		Int("warmed", result.Warmed).
		Int("skipped", result.Skipped).
		Int("failed", result.Failed).
		Msg("NATS media warm request completed")

	resp, _ := json.Marshal(result)
	msg.Respond(resp)
}

func (w *MediaWarmer) WarmMediaObjects(ctx context.Context, items []WarmMediaItem) WarmMediaResponse {
	urls := selectURLsToWarm(items)
	if len(urls) == 0 {
		return WarmMediaResponse{}
	}

	existingKeys := w.bulkExistsCheck(ctx, urls)

	var toWarm []string
	skipped := 0
	for _, u := range urls {
		key := urlToS3Key(u)
		if key == "" {
			continue
		}
		if existingKeys[key] {
			skipped++
		} else {
			toWarm = append(toWarm, u)
		}
	}

	if len(toWarm) == 0 {
		return WarmMediaResponse{Skipped: skipped}
	}

	var (
		mu     sync.Mutex
		warmed int
		failed int
		sem    = make(chan struct{}, w.cfg.MediaWarmingConcurrency)
	)

	var wg sync.WaitGroup
	for _, u := range toWarm {
		select {
		case <-ctx.Done():
			return WarmMediaResponse{Warmed: warmed, Skipped: skipped, Failed: failed, Error: "timeout"}
		default:
		}

		if err := w.limiter.Wait(ctx); err != nil {
			return WarmMediaResponse{Warmed: warmed, Skipped: skipped, Failed: failed, Error: "timeout"}
		}

		sem <- struct{}{}
		wg.Add(1)
		go func(mediaURL string) {
			defer wg.Done()
			defer func() { <-sem }()

			if w.warmSingleMedia(ctx, mediaURL) {
				mu.Lock()
				warmed++
				mu.Unlock()
			} else {
				mu.Lock()
				failed++
				mu.Unlock()
			}
		}(u)
	}
	wg.Wait()

	return WarmMediaResponse{Warmed: warmed, Skipped: skipped, Failed: failed}
}

func (w *MediaWarmer) warmSingleMedia(ctx context.Context, mediaURL string) bool {
	fileType, fileID, chatID, msgID, err := parseMediaURL(mediaURL)
	if err != nil {
		log.Warn().Err(err).Str("url", mediaURL).Msg("Failed to parse media URL for warming")
		return false
	}

	resp := downloadTelegramFile(ctx, w.client, GetFileRequest{
		FileID:   fileID,
		FileType: fileType,
		ChatID:   chatID,
		MsgID:    msgID,
	}, w.dbPool)

	if resp.Error != "" {
		log.Warn().Str("error", resp.Error).Str("file_id", fileID).Msg("Failed to download file for warming")
		return false
	}

	data, err := base64.StdEncoding.DecodeString(resp.Data)
	if err != nil {
		log.Warn().Err(err).Str("file_id", fileID).Msg("Failed to decode base64 for warming")
		return false
	}

	s3Key := fmt.Sprintf("%s/%s", fileType, fileID)
	mimeType := resp.MimeType
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	if err := w.s3Client.Upload(ctx, w.bucket, s3Key, bytes.NewReader(data), int64(len(data)), mimeType); err != nil {
		log.Warn().Err(err).Str("key", s3Key).Msg("Failed to upload to S3 for warming")
		return false
	}

	log.Debug().Str("key", s3Key).Int("size", len(data)).Msg("Media warmed to S3")
	return true
}

func (w *MediaWarmer) bulkExistsCheck(ctx context.Context, urls []string) map[string]bool {
	existing := make(map[string]bool)

	prefixes := make(map[string]bool)
	keySet := make(map[string]bool)
	for _, u := range urls {
		key := urlToS3Key(u)
		if key == "" {
			continue
		}
		keySet[key] = true
		parts := strings.SplitN(key, "/", 2)
		if len(parts) == 2 {
			prefixes[parts[0]+"/"] = true
		}
	}

	for prefix := range prefixes {
		keys, err := w.s3Client.ListPrefix(ctx, w.bucket, prefix)
		if err != nil {
			log.Warn().Err(err).Str("prefix", prefix).Msg("ListPrefix failed, will download individually")
			continue
		}
		for _, k := range keys {
			if keySet[k] {
				existing[k] = true
			}
		}
	}
	return existing
}

// selectURLsToWarm picks which URLs to warm: photos → URL, videos/animations → PreviewURL only.
func selectURLsToWarm(items []WarmMediaItem) []string {
	var urls []string
	for _, item := range items {
		switch item.Type {
		case "photo":
			if item.URL != "" {
				urls = append(urls, item.URL)
			}
		case "video", "animation":
			if item.PreviewURL != nil && *item.PreviewURL != "" {
				urls = append(urls, *item.PreviewURL)
			}
		}
	}
	return urls
}

// parseMediaURL extracts fileType, fileID, chatID, msgID from a media URL.
// URL format: {baseURL}/media/tg/{type}/{fileID}?chat={chatID}&msg={msgID}
func parseMediaURL(rawURL string) (fileType, fileID string, chatID int64, msgID int, err error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", "", 0, 0, fmt.Errorf("parse URL: %w", err)
	}

	path := strings.TrimPrefix(parsed.Path, "/")
	// Expected: media/tg/{type}/{fileID}
	parts := strings.Split(path, "/")

	// Find "tg" in path and take the next two segments
	tgIdx := -1
	for i, p := range parts {
		if p == "tg" {
			tgIdx = i
			break
		}
	}

	if tgIdx == -1 || tgIdx+2 >= len(parts) {
		return "", "", 0, 0, fmt.Errorf("invalid media URL path: %s", path)
	}

	fileType = parts[tgIdx+1]
	fileID, err = url.PathUnescape(parts[tgIdx+2])
	if err != nil {
		return "", "", 0, 0, fmt.Errorf("unescape fileID: %w", err)
	}

	if chatStr := parsed.Query().Get("chat"); chatStr != "" {
		chatID, _ = strconv.ParseInt(chatStr, 10, 64)
	}
	if msgStr := parsed.Query().Get("msg"); msgStr != "" {
		msgID, _ = strconv.Atoi(msgStr)
	}

	return fileType, fileID, chatID, msgID, nil
}

// urlToS3Key converts a media URL to an S3 key ({type}/{fileID}).
func urlToS3Key(rawURL string) string {
	fileType, fileID, _, _, err := parseMediaURL(rawURL)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%s/%s", fileType, fileID)
}
