package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type UsersFeedHandler struct {
	usersFeedRepo *repository.UsersFeedRepository
	feedRepo      *repository.FeedRepository
}

func NewUsersFeedHandler(
	usersFeedRepo *repository.UsersFeedRepository,
	feedRepo *repository.FeedRepository,
) *UsersFeedHandler {
	return &UsersFeedHandler{
		usersFeedRepo: usersFeedRepo,
		feedRepo:      feedRepo,
	}
}

func (h *UsersFeedHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/", h.Subscribe)
	r.Delete("/", h.Unsubscribe)

	return r
}

type SubscribeRequest struct {
	FeedID uuid.UUID `json:"feed_id"`
}

func (h *UsersFeedHandler) Subscribe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req SubscribeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	feed, err := h.feedRepo.GetByID(r.Context(), req.FeedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if feed == nil {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	if err := h.usersFeedRepo.Subscribe(r.Context(), userID, req.FeedID); err != nil {
		log.Error().Err(err).Msg("Failed to subscribe to feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "subscribed"})
}

func (h *UsersFeedHandler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := r.URL.Query().Get("feed_id")
	if feedIDStr == "" {
		http.Error(w, "feed_id is required", http.StatusBadRequest)
		return
	}

	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	if err := h.usersFeedRepo.Unsubscribe(r.Context(), userID, feedID); err != nil {
		log.Error().Err(err).Msg("Failed to unsubscribe from feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	subscriberCount, err := h.usersFeedRepo.CountFeedSubscribers(r.Context(), feedID)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to count feed subscribers")
	} else if subscriberCount == 0 {
		feed, _ := h.feedRepo.GetByID(r.Context(), feedID)
		if feed != nil && !feed.IsMarketplace {
			if err := h.feedRepo.Delete(r.Context(), feedID); err != nil {
				log.Warn().Err(err).Str("feed_id", feedID.String()).Msg("Failed to delete orphan feed")
			} else {
				log.Info().Str("feed_id", feedID.String()).Msg("Deleted orphan feed with no subscribers")
			}
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Unsubscribed from feed",
	})
}
