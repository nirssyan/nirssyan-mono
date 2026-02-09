package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type AdminHandler struct {
	suggestionRepo  *repository.SuggestionRepository
	tagRepo         *repository.TagRepository
	marketplaceRepo *repository.MarketplaceRepository
}

func NewAdminHandler(
	suggestionRepo *repository.SuggestionRepository,
	tagRepo *repository.TagRepository,
	marketplaceRepo *repository.MarketplaceRepository,
) *AdminHandler {
	return &AdminHandler{
		suggestionRepo:  suggestionRepo,
		tagRepo:         tagRepo,
		marketplaceRepo: marketplaceRepo,
	}
}

func (h *AdminHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/me", h.AdminMe)

	r.Get("/suggestions", h.ListSuggestions)
	r.Post("/suggestions", h.CreateSuggestion)
	r.Put("/suggestions/{id}", h.UpdateSuggestion)
	r.Delete("/suggestions/{id}", h.DeleteSuggestion)

	r.Get("/tags", h.ListTags)
	r.Post("/tags", h.CreateTag)
	r.Put("/tags/{id}", h.UpdateTag)
	r.Delete("/tags/{id}", h.DeleteTag)

	r.Get("/marketplace", h.ListMarketplaceFeeds)
	r.Get("/marketplace/{id}", h.GetMarketplaceFeed)
	r.Post("/marketplace", h.CreateMarketplaceFeed)
	r.Put("/marketplace/{id}", h.UpdateMarketplaceFeed)
	r.Delete("/marketplace/{id}", h.DeleteMarketplaceFeed)

	return r
}

func (h *AdminHandler) AdminMe(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]bool{"admin": true})
}

// --- Suggestions ---

type AdminSuggestionResponse struct {
	ID         string                 `json:"id"`
	Name       SuggestionNameResponse `json:"name"`
	Type       string                 `json:"type"`
	SourceType *string                `json:"source_type,omitempty"`
}

type CreateSuggestionRequest struct {
	Type       string                 `json:"type"`
	Name       SuggestionNameResponse `json:"name"`
	SourceType *string                `json:"source_type,omitempty"`
}

type UpdateSuggestionRequest struct {
	Name       *SuggestionNameResponse `json:"name,omitempty"`
	SourceType *string                 `json:"source_type,omitempty"`
}

func (h *AdminHandler) ListSuggestions(w http.ResponseWriter, r *http.Request) {
	typeFilter := r.URL.Query().Get("type")

	var suggestions []repository.Suggestion
	var err error

	if typeFilter != "" {
		suggestions, err = h.suggestionRepo.GetByType(r.Context(), typeFilter)
	} else {
		suggestions, err = h.suggestionRepo.GetAll(r.Context())
	}
	if err != nil {
		log.Error().Err(err).Msg("Failed to list suggestions")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]AdminSuggestionResponse, 0, len(suggestions))
	for _, s := range suggestions {
		response = append(response, AdminSuggestionResponse{
			ID:         s.ID.String(),
			Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
			Type:       s.Type,
			SourceType: s.SourceType,
		})
	}

	writeJSON(w, http.StatusOK, response)
}

func (h *AdminHandler) CreateSuggestion(w http.ResponseWriter, r *http.Request) {
	var req CreateSuggestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Type == "" || (req.Name.En == "" && req.Name.Ru == "") {
		http.Error(w, "type and name are required", http.StatusBadRequest)
		return
	}

	if req.Type != "filter" && req.Type != "view" && req.Type != "source" {
		http.Error(w, "type must be filter, view, or source", http.StatusBadRequest)
		return
	}

	name := repository.SuggestionName{En: req.Name.En, Ru: req.Name.Ru}
	s, err := h.suggestionRepo.Create(r.Context(), req.Type, name, req.SourceType)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create suggestion")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, AdminSuggestionResponse{
		ID:         s.ID.String(),
		Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
		Type:       s.Type,
		SourceType: s.SourceType,
	})
}

func (h *AdminHandler) UpdateSuggestion(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	var req UpdateSuggestionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	var name *repository.SuggestionName
	if req.Name != nil {
		name = &repository.SuggestionName{En: req.Name.En, Ru: req.Name.Ru}
	}

	s, err := h.suggestionRepo.Update(r.Context(), id, name, req.SourceType)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to update suggestion")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, AdminSuggestionResponse{
		ID:         s.ID.String(),
		Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
		Type:       s.Type,
		SourceType: s.SourceType,
	})
}

func (h *AdminHandler) DeleteSuggestion(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.suggestionRepo.Delete(r.Context(), id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to delete suggestion")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// --- Tags ---

type CreateTagRequest struct {
	Name string `json:"name"`
	Slug string `json:"slug"`
}

type UpdateTagRequest struct {
	Name *string `json:"name,omitempty"`
	Slug *string `json:"slug,omitempty"`
}

func (h *AdminHandler) ListTags(w http.ResponseWriter, r *http.Request) {
	tags, err := h.tagRepo.GetAll(r.Context())
	if err != nil {
		log.Error().Err(err).Msg("Failed to list tags")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]TagResponse, 0, len(tags))
	for _, t := range tags {
		response = append(response, TagResponse{
			ID:   t.ID.String(),
			Name: t.Name,
			Slug: t.Slug,
		})
	}

	writeJSON(w, http.StatusOK, response)
}

func (h *AdminHandler) CreateTag(w http.ResponseWriter, r *http.Request) {
	var req CreateTagRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" || req.Slug == "" {
		http.Error(w, "name and slug are required", http.StatusBadRequest)
		return
	}

	t, err := h.tagRepo.Create(r.Context(), req.Name, req.Slug)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create tag")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, TagResponse{
		ID:   t.ID.String(),
		Name: t.Name,
		Slug: t.Slug,
	})
}

func (h *AdminHandler) UpdateTag(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	var req UpdateTagRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	t, err := h.tagRepo.Update(r.Context(), id, req.Name, req.Slug)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to update tag")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, TagResponse{
		ID:   t.ID.String(),
		Name: t.Name,
		Slug: t.Slug,
	})
}

func (h *AdminHandler) DeleteTag(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.tagRepo.Delete(r.Context(), id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to delete tag")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// --- Marketplace ---

type CreateAdminMarketplaceFeedRequest struct {
	Name        string                  `json:"name"`
	Description string                  `json:"description"`
	FeedType    string                  `json:"feed_type"`
	Tags        []string                `json:"tags"`
	Sources     []MarketplaceFeedSource `json:"sources"`
	Story       string                  `json:"story"`
}

type UpdateMarketplaceFeedRequest struct {
	Name        *string                  `json:"name,omitempty"`
	Description *string                  `json:"description,omitempty"`
	FeedType    *string                  `json:"feed_type,omitempty"`
	Tags        []string                 `json:"tags,omitempty"`
	Sources     *[]MarketplaceFeedSource `json:"sources,omitempty"`
	Story       *string                  `json:"story,omitempty"`
}

func (h *AdminHandler) ListMarketplaceFeeds(w http.ResponseWriter, r *http.Request) {
	feeds, err := h.marketplaceRepo.GetAll(r.Context(), 100, 0)
	if err != nil {
		log.Error().Err(err).Msg("Failed to list marketplace feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]MarketplaceFeedResponse, 0, len(feeds))
	for _, f := range feeds {
		response = append(response, toMarketplaceFeedResponse(f))
	}

	writeJSON(w, http.StatusOK, response)
}

func (h *AdminHandler) GetMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	feed, err := h.marketplaceRepo.GetByID(r.Context(), id)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get marketplace feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if feed == nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	writeJSON(w, http.StatusOK, toMarketplaceFeedResponse(*feed))
}

func (h *AdminHandler) CreateMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	var req CreateAdminMarketplaceFeedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}
	if req.FeedType != "SINGLE_POST" && req.FeedType != "DIGEST" {
		http.Error(w, "feed_type must be SINGLE_POST or DIGEST", http.StatusBadRequest)
		return
	}

	slug := slugify(req.Name)

	sourcesJSON, err := json.Marshal(req.Sources)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	var desc *string
	if req.Description != "" {
		desc = &req.Description
	}
	var story *string
	if req.Story != "" {
		story = &req.Story
	}

	feed, err := h.marketplaceRepo.Create(r.Context(), repository.CreateMarketplaceFeedParams{
		Slug:        slug,
		Name:        req.Name,
		Type:        req.FeedType,
		Description: desc,
		Tags:        req.Tags,
		Sources:     sourcesJSON,
		Story:       story,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create marketplace feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, toMarketplaceFeedResponse(*feed))
}

func (h *AdminHandler) UpdateMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	var req UpdateMarketplaceFeedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	params := repository.UpdateMarketplaceFeedParams{
		Name:        req.Name,
		Type:        req.FeedType,
		Description: req.Description,
		Tags:        req.Tags,
		Story:       req.Story,
	}

	if req.Sources != nil {
		sourcesJSON, err := json.Marshal(req.Sources)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		params.Sources = sourcesJSON
	}

	feed, err := h.marketplaceRepo.Update(r.Context(), id, params)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to update marketplace feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, toMarketplaceFeedResponse(*feed))
}

func (h *AdminHandler) DeleteMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.marketplaceRepo.Delete(r.Context(), id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Error().Err(err).Msg("Failed to delete marketplace feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
