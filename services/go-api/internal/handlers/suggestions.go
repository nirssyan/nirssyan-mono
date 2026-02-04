package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type SuggestionsHandler struct {
	suggestionRepo *repository.SuggestionRepository
}

func NewSuggestionsHandler(suggestionRepo *repository.SuggestionRepository) *SuggestionsHandler {
	return &SuggestionsHandler{suggestionRepo: suggestionRepo}
}

func (h *SuggestionsHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/filters", h.GetFilterSuggestions)
	r.Get("/views", h.GetViewSuggestions)
	r.Get("/sources", h.GetSourceSuggestions)

	return r
}

type SuggestionNameResponse struct {
	En string `json:"en"`
	Ru string `json:"ru"`
}

type SuggestionResponse struct {
	ID         string                 `json:"id"`
	Name       SuggestionNameResponse `json:"name"`
	SourceType *string                `json:"source_type,omitempty"`
}

func (h *SuggestionsHandler) GetFilterSuggestions(w http.ResponseWriter, r *http.Request) {
	suggestions, err := h.suggestionRepo.GetByType(r.Context(), "filter")
	if err != nil {
		log.Error().Err(err).Msg("Failed to get filter suggestions")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]SuggestionResponse, 0, len(suggestions))
	for _, s := range suggestions {
		response = append(response, SuggestionResponse{
			ID:         s.ID.String(),
			Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
			SourceType: s.SourceType,
		})
	}

	writeJSON(w, http.StatusOK, response)
}

func (h *SuggestionsHandler) GetViewSuggestions(w http.ResponseWriter, r *http.Request) {
	suggestions, err := h.suggestionRepo.GetByType(r.Context(), "view")
	if err != nil {
		log.Error().Err(err).Msg("Failed to get view suggestions")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]SuggestionResponse, 0, len(suggestions))
	for _, s := range suggestions {
		response = append(response, SuggestionResponse{
			ID:         s.ID.String(),
			Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
			SourceType: s.SourceType,
		})
	}

	writeJSON(w, http.StatusOK, response)
}

func (h *SuggestionsHandler) GetSourceSuggestions(w http.ResponseWriter, r *http.Request) {
	suggestions, err := h.suggestionRepo.GetByType(r.Context(), "source")
	if err != nil {
		log.Error().Err(err).Msg("Failed to get source suggestions")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]SuggestionResponse, 0, len(suggestions))
	for _, s := range suggestions {
		response = append(response, SuggestionResponse{
			ID:         s.ID.String(),
			Name:       SuggestionNameResponse{En: s.Name.En, Ru: s.Name.Ru},
			SourceType: s.SourceType,
		})
	}

	writeJSON(w, http.StatusOK, response)
}
