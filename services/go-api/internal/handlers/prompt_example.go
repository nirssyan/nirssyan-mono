package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type PromptExamplesHandler struct {
	repo *repository.PromptExampleRepository
}

func NewPromptExamplesHandler(repo *repository.PromptExampleRepository) *PromptExamplesHandler {
	return &PromptExamplesHandler{repo: repo}
}

func (h *PromptExamplesHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.GetPromptExamples)
	return r
}

type PromptExampleResponse struct {
	ID        string   `json:"id"`
	Prompt    string   `json:"prompt"`
	Tags      []string `json:"tags"`
	CreatedAt string   `json:"created_at"`
}

type PromptExamplesListResponse struct {
	Data []PromptExampleResponse `json:"data"`
}

func (h *PromptExamplesHandler) GetPromptExamples(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	examples, err := h.repo.GetByUserTags(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get prompt examples")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]PromptExampleResponse, 0, len(examples))
	for _, pe := range examples {
		response = append(response, PromptExampleResponse{
			ID:        pe.ID.String(),
			Prompt:    pe.Prompt,
			Tags:      pe.Tags,
			CreatedAt: pe.CreatedAt.Format(time.RFC3339),
		})
	}

	writeJSON(w, http.StatusOK, PromptExamplesListResponse{Data: response})
}
