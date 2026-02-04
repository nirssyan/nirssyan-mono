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

type TagsHandler struct {
	tagRepo     *repository.TagRepository
	userTagRepo *repository.UserTagRepository
}

func NewTagsHandler(tagRepo *repository.TagRepository, userTagRepo *repository.UserTagRepository) *TagsHandler {
	return &TagsHandler{
		tagRepo:     tagRepo,
		userTagRepo: userTagRepo,
	}
}

func (h *TagsHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.GetAllTags)

	return r
}

func (h *TagsHandler) AuthenticatedRoutes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.GetUserTags)
	r.Put("/", h.UpdateUserTags)

	return r
}

type TagResponse struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

func (h *TagsHandler) GetAllTags(w http.ResponseWriter, r *http.Request) {
	tags, err := h.tagRepo.GetAll(r.Context())
	if err != nil {
		log.Error().Err(err).Msg("Failed to get tags")
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

func (h *TagsHandler) GetUserTags(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	tags, err := h.userTagRepo.GetUserTags(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get user tags")
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

type UpdateUserTagsRequest struct {
	TagIDs []string `json:"tag_ids"`
}

func (h *TagsHandler) UpdateUserTags(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req UpdateUserTagsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if len(req.TagIDs) > 10 {
		http.Error(w, "maximum 10 tags allowed", http.StatusBadRequest)
		return
	}

	if len(req.TagIDs) > 0 {
		tagUUIDs := make([]uuid.UUID, 0, len(req.TagIDs))
		for _, idStr := range req.TagIDs {
			id, err := uuid.Parse(idStr)
			if err != nil {
				http.Error(w, "invalid tag_id: "+idStr, http.StatusBadRequest)
				return
			}
			tagUUIDs = append(tagUUIDs, id)
		}

		validIDs, err := h.tagRepo.ValidateTagIDs(r.Context(), tagUUIDs)
		if err != nil {
			log.Error().Err(err).Msg("Failed to validate tag IDs")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		if len(validIDs) != len(tagUUIDs) {
			http.Error(w, "one or more tag_ids are invalid", http.StatusBadRequest)
			return
		}
	}

	if err := h.userTagRepo.SetUserTags(r.Context(), userID, req.TagIDs); err != nil {
		log.Error().Err(err).Msg("Failed to update user tags")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Tags updated successfully",
	})
}
