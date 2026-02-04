package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type DeviceTokenHandler struct {
	deviceTokenRepo *repository.DeviceTokenRepository
}

func NewDeviceTokenHandler(deviceTokenRepo *repository.DeviceTokenRepository) *DeviceTokenHandler {
	return &DeviceTokenHandler{deviceTokenRepo: deviceTokenRepo}
}

func (h *DeviceTokenHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/", h.RegisterToken)
	r.Delete("/", h.UnregisterToken)

	return r
}

type RegisterTokenRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

func (h *DeviceTokenHandler) RegisterToken(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req RegisterTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Token == "" || req.Platform == "" {
		http.Error(w, "token and platform are required", http.StatusBadRequest)
		return
	}

	token, isNew, err := h.deviceTokenRepo.Upsert(r.Context(), userID, req.Token, req.Platform)
	if err != nil {
		log.Error().Err(err).Msg("Failed to register device token")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	status := http.StatusOK
	if isNew {
		status = http.StatusCreated
	}

	writeJSON(w, status, map[string]interface{}{
		"id":         token.ID,
		"user_id":    token.UserID,
		"platform":   token.Platform,
		"created_at": token.CreatedAt.Format("2006-01-02T15:04:05Z"),
		"is_new":     isNew,
	})
}

type UnregisterTokenRequest struct {
	Token string `json:"token"`
}

func (h *DeviceTokenHandler) UnregisterToken(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req UnregisterTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Token == "" {
		http.Error(w, "token is required", http.StatusBadRequest)
		return
	}

	if err := h.deviceTokenRepo.Delete(r.Context(), userID, req.Token); err != nil {
		log.Error().Err(err).Msg("Failed to unregister device token")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Device token unregistered successfully",
	})
}
