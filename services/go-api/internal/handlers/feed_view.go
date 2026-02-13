package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type FeedViewHandler struct {
	feedRepo    *repository.FeedRepository
	postRepo    *repository.PostRepository
	rawFeedRepo *repository.RawFeedRepository
	agents      *clients.AgentsClient
}

func NewFeedViewHandler(
	feedRepo *repository.FeedRepository,
	postRepo *repository.PostRepository,
	rawFeedRepo *repository.RawFeedRepository,
	agents *clients.AgentsClient,
) *FeedViewHandler {
	return &FeedViewHandler{
		feedRepo:    feedRepo,
		postRepo:    postRepo,
		rawFeedRepo: rawFeedRepo,
		agents:      agents,
	}
}

func (h *FeedViewHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/feed/{feed_id}", h.GetFeedModal)
	r.Get("/generate_title/{feed_id}", h.GenerateFeedTitle)

	return r
}

type FeedModalResponse struct {
	ID          uuid.UUID       `json:"id"`
	Name        string          `json:"name"`
	Type        string          `json:"type"`
	Description *string         `json:"description,omitempty"`
	PostsCount  int             `json:"posts_count"`
	Sources     []SourceItem    `json:"sources"`
	Views       json.RawMessage `json:"views,omitempty"`
	Filters     json.RawMessage `json:"filters,omitempty"`
}

type SourceItem struct {
	En   string `json:"en"`
	Ru   string `json:"ru"`
	URL  string `json:"url"`
	Type string `json:"type"`
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

	feed, err := h.feedRepo.GetFeedWithPrompt(r.Context(), feedID)
	if err != nil || feed == nil {
		plainFeed, err2 := h.feedRepo.GetByID(r.Context(), feedID)
		if err2 != nil || plainFeed == nil {
			http.Error(w, "feed not found", http.StatusNotFound)
			return
		}
		postsCount, _ := h.postRepo.CountByFeedID(r.Context(), feedID)
		writeJSON(w, http.StatusOK, FeedModalResponse{
			ID:          plainFeed.ID,
			Name:        plainFeed.Name,
			Type:        plainFeed.Type,
			Description: plainFeed.Description,
			PostsCount:  postsCount,
			Sources:     []SourceItem{},
		})
		return
	}

	postsCount, _ := h.postRepo.CountByFeedID(r.Context(), feedID)

	rawFeeds, err := h.rawFeedRepo.GetByFeedID(r.Context(), feedID)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to get raw feeds for modal")
	}
	sources := make([]SourceItem, 0, len(rawFeeds))
	for _, rf := range rawFeeds {
		sources = append(sources, SourceItem{
			En:   rf.Name,
			Ru:   rf.Name,
			URL:  rf.FeedURL,
			Type: rf.RawType,
		})
	}

	var viewsJSON, filtersJSON json.RawMessage
	if feed.ViewsConfig != nil {
		viewsJSON, _ = json.Marshal(feed.ViewsConfig)
	}
	if feed.FiltersConfig != nil {
		filtersJSON, _ = json.Marshal(feed.FiltersConfig)
	}

	writeJSON(w, http.StatusOK, FeedModalResponse{
		ID:          feed.ID,
		Name:        feed.Name,
		Type:        feed.Type,
		Description: feed.Description,
		PostsCount:  postsCount,
		Sources:     sources,
		Views:       viewsJSON,
		Filters:     filtersJSON,
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
