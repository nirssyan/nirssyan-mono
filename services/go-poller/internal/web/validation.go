package web

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/web/discovery"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	natsgo "github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

const (
	ValidationSubject = "web.validate"
	ValidationQueue   = "web-validators"
)

type ValidationHandler struct {
	pipeline   *discovery.Pipeline
	httpClient *http.Client
}

func NewValidationHandler(httpClient *http.Client) *ValidationHandler {
	return &ValidationHandler{
		pipeline:   discovery.NewPipeline(httpClient),
		httpClient: httpClient,
	}
}

func (h *ValidationHandler) Register(nc *natsgo.Conn) error {
	_, err := nc.QueueSubscribe(ValidationSubject, ValidationQueue, h.handleRequest)
	if err != nil {
		return err
	}

	log.Info().
		Str("subject", ValidationSubject).
		Str("queue", ValidationQueue).
		Msg("Registered web validation handler")

	return nil
}

func (h *ValidationHandler) handleRequest(msg *natsgo.Msg) {
	var req domain.WebValidationRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		log.Error().Err(err).Msg("Failed to unmarshal validation request")
		h.respondWithError(msg, req.RequestID, "invalid request format")
		return
	}

	log.Debug().
		Str("request_id", req.RequestID.String()).
		Str("url", req.URL).
		Bool("lightweight", req.Lightweight).
		Msg("Handling web validation request")

	ctx := context.Background()

	resp := h.validate(ctx, req)

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal validation response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send validation response")
	}
}

func (h *ValidationHandler) validate(ctx context.Context, req domain.WebValidationRequest) domain.WebValidationResponse {
	if req.Lightweight {
		return h.lightweightValidation(ctx, req)
	}

	return h.fullValidation(ctx, req)
}

func (h *ValidationHandler) lightweightValidation(ctx context.Context, req domain.WebValidationRequest) domain.WebValidationResponse {
	resp, err := h.httpClient.Head(ctx, req.URL)
	if err != nil {
		return domain.WebValidationResponse{
			RequestID: req.RequestID,
			Valid:     false,
			Error:     err.Error(),
		}
	}

	if resp.StatusCode != 200 {
		return domain.WebValidationResponse{
			RequestID: req.RequestID,
			Valid:     false,
			Error:     "URL returned non-200 status",
		}
	}

	return domain.WebValidationResponse{
		RequestID: req.RequestID,
		Valid:     true,
	}
}

func (h *ValidationHandler) fullValidation(ctx context.Context, req domain.WebValidationRequest) domain.WebValidationResponse {
	result, err := h.pipeline.Discover(ctx, req.URL, 1, "")
	if err != nil {
		return domain.WebValidationResponse{
			RequestID: req.RequestID,
			Valid:     false,
			Error:     err.Error(),
		}
	}

	if result == nil || len(result.Articles) == 0 {
		return domain.WebValidationResponse{
			RequestID: req.RequestID,
			Valid:     false,
			Error:     "No articles found at URL",
		}
	}

	return domain.WebValidationResponse{
		RequestID:       req.RequestID,
		Valid:           true,
		SourceType:      result.SourceType,
		DetectedFeedURL: result.FeedURL,
	}
}

func (h *ValidationHandler) respondWithError(msg *natsgo.Msg, requestID uuid.UUID, errMsg string) {
	resp := domain.WebValidationResponse{
		RequestID: requestID,
		Valid:     false,
		Error:     errMsg,
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
