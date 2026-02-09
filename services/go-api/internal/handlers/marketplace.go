package handlers

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
	"golang.org/x/text/runes"
	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

type MarketplaceHandler struct {
	marketplaceRepo  *repository.MarketplaceRepository
	validationClient *clients.ValidationClient
}

func NewMarketplaceHandler(marketplaceRepo *repository.MarketplaceRepository, validationClient *clients.ValidationClient) *MarketplaceHandler {
	return &MarketplaceHandler{
		marketplaceRepo:  marketplaceRepo,
		validationClient: validationClient,
	}
}

func (h *MarketplaceHandler) Routes(authMw func(http.Handler) http.Handler) chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.GetMarketplaceFeeds)
	r.Get("/{slug}", h.GetMarketplaceFeed)
	r.With(authMw).Post("/", h.CreateMarketplaceFeed)
	return r
}

type MarketplaceFeedSource struct {
	Name string `json:"name"`
	URL  string `json:"url"`
	Type string `json:"type"`
}

type MarketplaceFeedResponse struct {
	ID          uuid.UUID               `json:"id"`
	Slug        string                  `json:"slug"`
	Name        string                  `json:"name"`
	Type        string                  `json:"type"`
	Description *string                 `json:"description,omitempty"`
	Tags        []string                `json:"tags"`
	Sources     []MarketplaceFeedSource `json:"sources"`
	Story       *string                 `json:"story,omitempty"`
	CreatedAt   time.Time               `json:"created_at"`
}

type MarketplaceListResponse struct {
	Data []MarketplaceFeedResponse `json:"data"`
}

type CreateMarketplaceFeedRequest struct {
	Name        string                  `json:"name"`
	Description string                  `json:"description"`
	FeedType    string                  `json:"feed_type"`
	Tags        []string                `json:"tags"`
	Sources     []MarketplaceFeedSource `json:"sources"`
	Story       string                  `json:"story"`
}

func (h *MarketplaceHandler) GetMarketplaceFeeds(w http.ResponseWriter, r *http.Request) {
	limit := 20
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	offset := 0
	if o := r.URL.Query().Get("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	feeds, err := h.marketplaceRepo.GetAll(r.Context(), limit, offset)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get marketplace feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]MarketplaceFeedResponse, 0, len(feeds))
	for _, f := range feeds {
		response = append(response, toMarketplaceFeedResponse(f))
	}

	writeJSON(w, http.StatusOK, MarketplaceListResponse{Data: response})
}

func (h *MarketplaceHandler) GetMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	feed, err := h.marketplaceRepo.GetBySlug(r.Context(), slug)
	if err != nil {
		log.Error().Err(err).Str("slug", slug).Msg("Failed to get marketplace feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if feed == nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	writeJSON(w, http.StatusOK, toMarketplaceFeedResponse(*feed))
}

func (h *MarketplaceHandler) CreateMarketplaceFeed(w http.ResponseWriter, r *http.Request) {
	var req CreateMarketplaceFeedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}

	if req.FeedType != "SINGLE_POST" && req.FeedType != "DIGEST" {
		http.Error(w, "feed_type must be SINGLE_POST or DIGEST", http.StatusBadRequest)
		return
	}

	if len(req.Sources) == 0 {
		http.Error(w, "at least one source is required", http.StatusBadRequest)
		return
	}

	for i, src := range req.Sources {
		src.URL = strings.TrimSpace(src.URL)
		if src.URL == "" {
			http.Error(w, "source URL is required", http.StatusBadRequest)
			return
		}

		result, err := h.validationClient.ValidateSource(r.Context(), src.URL, src.Type, true)
		if err != nil {
			log.Error().Err(err).Str("url", src.URL).Msg("Failed to validate source")
			http.Error(w, "failed to validate source: "+src.URL, http.StatusBadRequest)
			return
		}

		if !result.Valid {
			msg := "invalid source: " + src.URL
			if result.Message != nil {
				msg = *result.Message
			}
			http.Error(w, msg, http.StatusBadRequest)
			return
		}

		if result.SourceType != nil {
			src.Type = strings.ToLower(*result.SourceType)
		}
		if src.Name == "" && result.Title != nil {
			src.Name = *result.Title
		}
		req.Sources[i] = src
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

func toMarketplaceFeedResponse(f repository.MarketplaceFeed) MarketplaceFeedResponse {
	var sources []MarketplaceFeedSource
	if f.Sources != nil {
		json.Unmarshal(f.Sources, &sources)
	}
	if sources == nil {
		sources = []MarketplaceFeedSource{}
	}

	tags := f.Tags
	if tags == nil {
		tags = []string{}
	}

	return MarketplaceFeedResponse{
		ID:          f.ID,
		Slug:        f.Slug,
		Name:        f.Name,
		Type:        f.Type,
		Description: f.Description,
		Tags:        tags,
		Sources:     sources,
		Story:       f.Story,
		CreatedAt:   f.CreatedAt,
	}
}

var nonAlphanumRegex = regexp.MustCompile(`[^a-z0-9]+`)
var multiDashRegex = regexp.MustCompile(`-{2,}`)

func slugify(s string) string {
	t := transform.Chain(norm.NFD, runes.Remove(runes.In(unicode.Mn)), norm.NFC)
	result, _, _ := transform.String(t, s)
	result = strings.ToLower(result)
	result = nonAlphanumRegex.ReplaceAllString(result, "-")
	result = multiDashRegex.ReplaceAllString(result, "-")
	result = strings.Trim(result, "-")
	if result == "" {
		result = "feed"
	}
	return result
}
