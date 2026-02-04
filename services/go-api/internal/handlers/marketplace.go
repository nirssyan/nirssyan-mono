package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type MarketplaceHandler struct {
	marketplaceRepo *repository.MarketplaceRepository
}

func NewMarketplaceHandler(marketplaceRepo *repository.MarketplaceRepository) *MarketplaceHandler {
	return &MarketplaceHandler{marketplaceRepo: marketplaceRepo}
}

func (h *MarketplaceHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.GetMarketplaceFeeds)

	return r
}

type MarketplaceFeedResponse struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"`
	Description *string   `json:"description,omitempty"`
	Tags        []string  `json:"tags"`
}

type MarketplaceResponse struct {
	Data []MarketplaceFeedResponse `json:"data"`
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

	feeds, err := h.marketplaceRepo.GetMarketplaceFeeds(r.Context(), limit, offset)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get marketplace feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]MarketplaceFeedResponse, 0, len(feeds))
	for _, f := range feeds {
		response = append(response, MarketplaceFeedResponse{
			ID:          f.ID,
			Name:        f.Name,
			Type:        f.Type,
			Description: f.Description,
			Tags:        f.Tags,
		})
	}

	writeJSON(w, http.StatusOK, MarketplaceResponse{Data: response})
}
