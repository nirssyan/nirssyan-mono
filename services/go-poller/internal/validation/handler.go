package validation

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/rss"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/telegram"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/web/discovery"
	pollerhttp "github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	natsgo "github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

const (
	ValidationSubject = "validation.validate_source"
	ValidationQueue   = "source-validators"
)

type ValidateRequest struct {
	URL         string `json:"url"`
	SourceType  string `json:"source_type"`
	Lightweight bool   `json:"lightweight"`
}

type ValidateResponse struct {
	Valid       bool    `json:"valid"`
	Title       *string `json:"title,omitempty"`
	Description *string `json:"description,omitempty"`
	Error       *string `json:"error,omitempty"`
}

type Handler struct {
	httpClient     *pollerhttp.Client
	rssParser      *rss.Parser
	telegramClient *telegram.Client
	webPipeline    *discovery.Pipeline
}

func NewHandler(
	httpClient *pollerhttp.Client,
	rssParser *rss.Parser,
	telegramClient *telegram.Client,
) *Handler {
	return &Handler{
		httpClient:     httpClient,
		rssParser:      rssParser,
		telegramClient: telegramClient,
		webPipeline:    discovery.NewPipeline(httpClient),
	}
}

func (h *Handler) Register(nc *natsgo.Conn) error {
	_, err := nc.QueueSubscribe(ValidationSubject, ValidationQueue, h.handleRequest)
	if err != nil {
		return err
	}

	log.Info().
		Str("subject", ValidationSubject).
		Str("queue", ValidationQueue).
		Msg("Registered unified source validation handler")

	return nil
}

func (h *Handler) handleRequest(msg *natsgo.Msg) {
	var req ValidateRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		log.Error().Err(err).Msg("Failed to unmarshal validation request")
		h.respondWithError(msg, "invalid request format")
		return
	}

	log.Debug().
		Str("url", req.URL).
		Str("source_type", req.SourceType).
		Bool("lightweight", req.Lightweight).
		Msg("Handling source validation request")

	ctx := context.Background()

	var resp ValidateResponse
	switch req.SourceType {
	case "telegram":
		resp = h.validateTelegram(ctx, req)
	case "rss":
		resp = h.validateRSS(ctx, req)
	case "web":
		resp = h.validateWeb(ctx, req)
	default:
		resp = h.validateWeb(ctx, req)
	}

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal validation response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send validation response")
	}
}

func (h *Handler) validateTelegram(ctx context.Context, req ValidateRequest) ValidateResponse {
	if h.telegramClient == nil {
		return ValidateResponse{
			Valid: false,
			Error: ptr("telegram validation not available"),
		}
	}

	if !h.telegramClient.IsConnected() {
		return ValidateResponse{
			Valid: false,
			Error: ptr("telegram client not connected"),
		}
	}

	username := extractTelegramUsername(req.URL)
	if username == "" {
		return ValidateResponse{
			Valid: false,
			Error: ptr("invalid telegram URL format"),
		}
	}

	info, err := h.telegramClient.GetChannelInfo(ctx, username)
	if err != nil {
		return ValidateResponse{
			Valid: false,
			Error: ptr(err.Error()),
		}
	}

	return ValidateResponse{
		Valid: true,
		Title: &info.Title,
	}
}

func (h *Handler) validateRSS(ctx context.Context, req ValidateRequest) ValidateResponse {
	if h.rssParser == nil {
		return ValidateResponse{
			Valid: false,
			Error: ptr("rss validation not available"),
		}
	}

	if req.Lightweight {
		resp, err := h.httpClient.Head(ctx, req.URL)
		if err != nil {
			return ValidateResponse{
				Valid: false,
				Error: ptr(err.Error()),
			}
		}
		if resp.StatusCode != 200 {
			return ValidateResponse{
				Valid: false,
				Error: ptr("URL returned non-200 status"),
			}
		}
		return ValidateResponse{Valid: true}
	}

	items, err := h.rssParser.ParseFeed(ctx, req.URL)
	if err != nil {
		return ValidateResponse{
			Valid: false,
			Error: ptr(err.Error()),
		}
	}

	if len(items) == 0 {
		return ValidateResponse{
			Valid: false,
			Error: ptr("no items found in feed"),
		}
	}

	return ValidateResponse{Valid: true}
}

func (h *Handler) validateWeb(ctx context.Context, req ValidateRequest) ValidateResponse {
	if req.Lightweight {
		resp, err := h.httpClient.Head(ctx, req.URL)
		if err != nil {
			return ValidateResponse{
				Valid: false,
				Error: ptr(err.Error()),
			}
		}
		if resp.StatusCode != 200 {
			return ValidateResponse{
				Valid: false,
				Error: ptr("URL returned non-200 status"),
			}
		}
		return ValidateResponse{Valid: true}
	}

	result, err := h.webPipeline.Discover(ctx, req.URL, 1, "")
	if err != nil {
		return ValidateResponse{
			Valid: false,
			Error: ptr(err.Error()),
		}
	}

	if result == nil || len(result.Articles) == 0 {
		return ValidateResponse{
			Valid: false,
			Error: ptr("no articles found at URL"),
		}
	}

	return ValidateResponse{Valid: true}
}

func (h *Handler) respondWithError(msg *natsgo.Msg, errMsg string) {
	resp := ValidateResponse{
		Valid: false,
		Error: &errMsg,
	}

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal error response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send error response")
	}
}

func extractTelegramUsername(url string) string {
	url = strings.TrimSpace(url)
	url = strings.ToLower(url)

	prefixes := []string{
		"https://t.me/",
		"http://t.me/",
		"https://telegram.me/",
		"http://telegram.me/",
		"t.me/",
		"telegram.me/",
		"@",
	}

	for _, prefix := range prefixes {
		if strings.HasPrefix(url, prefix) {
			username := strings.TrimPrefix(url, prefix)
			username = strings.Split(username, "/")[0]
			username = strings.Split(username, "?")[0]
			return username
		}
	}

	if !strings.Contains(url, "/") && !strings.Contains(url, ".") {
		return url
	}

	return ""
}

func ptr(s string) *string {
	return &s
}
