package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/rs/zerolog/log"
)

type TelegramSyncHandler struct {
	telegramClient *clients.TelegramClient
}

func NewTelegramSyncHandler(telegramClient *clients.TelegramClient) *TelegramSyncHandler {
	return &TelegramSyncHandler{telegramClient: telegramClient}
}

func (h *TelegramSyncHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/update-channels", h.UpdateChannels)

	return r
}

type UpdateChannelsResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func (h *TelegramSyncHandler) UpdateChannels(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if err := h.telegramClient.TriggerSync(r.Context()); err != nil {
		log.Error().Err(err).Msg("Failed to trigger telegram sync")
		http.Error(w, "failed to trigger sync", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, UpdateChannelsResponse{
		Status:  "ok",
		Message: "Sync triggered successfully",
	})
}
