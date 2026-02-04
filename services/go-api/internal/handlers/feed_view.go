package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type FeedViewHandler struct {
	feedRepo *repository.FeedRepository
	postRepo *repository.PostRepository
	agents   *clients.AgentsClient
}

func NewFeedViewHandler(
	feedRepo *repository.FeedRepository,
	postRepo *repository.PostRepository,
	agents *clients.AgentsClient,
) *FeedViewHandler {
	return &FeedViewHandler{
		feedRepo: feedRepo,
		postRepo: postRepo,
		agents:   agents,
	}
}

func (h *FeedViewHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/feed/{feed_id}", h.GetFeedModal)
	r.Get("/generate_title/{feed_id}", h.GenerateFeedTitle)

	return r
}

type FeedModalResponse struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"`
	Description *string   `json:"description,omitempty"`
	PostsCount  int       `json:"posts_count"`
	Sources     []string  `json:"sources,omitempty"`
}

func (h *FeedViewHandler) GetFeedModal(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := chi.URLParam(r, "feed_id")
	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	feed, err := h.feedRepo.GetByID(r.Context(), feedID)
	if err != nil || feed == nil {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	posts, err := h.postRepo.GetFeedPosts(r.Context(), feedID, 100, 0)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get feed posts")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, FeedModalResponse{
		ID:          feed.ID,
		Name:        feed.Name,
		Type:        feed.Type,
		Description: feed.Description,
		PostsCount:  len(posts),
	})
}

func (h *FeedViewHandler) GenerateFeedTitle(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := chi.URLParam(r, "feed_id")
	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	feed, err := h.feedRepo.GetByID(r.Context(), feedID)
	if err != nil || feed == nil {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	title, err := h.agents.GenerateFeedTitle(r.Context(), []clients.SourceInfo{
		{Title: feed.Name, Description: stringValue(feed.Description)},
	}, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to generate title")
		http.Error(w, "failed to generate title", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, GenerateTitleResponse{Title: title})
}

func stringValue(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
