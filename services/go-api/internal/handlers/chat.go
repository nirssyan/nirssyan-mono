package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/rs/zerolog/log"
)

type ChatHandler struct {
	openclawClient *clients.OpenClawClient
}

func NewChatHandler(openclawClient *clients.OpenClawClient) *ChatHandler {
	return &ChatHandler{openclawClient: openclawClient}
}

func (h *ChatHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/message", h.SendMessage)
	return r
}

type chatMessageRequest struct {
	Message string `json:"message"`
}

type chatMessageResponse struct {
	Response string `json:"response"`
}

func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	if h.openclawClient == nil {
		http.Error(w, "chat service not configured", http.StatusNotImplemented)
		return
	}

	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req chatMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Message == "" {
		http.Error(w, "message is required", http.StatusBadRequest)
		return
	}

	resp, err := h.openclawClient.SendMessage(r.Context(), userID.String(), req.Message)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("Failed to send message to OpenClaw")
		http.Error(w, "chat service unavailable", http.StatusBadGateway)
		return
	}

	writeJSON(w, http.StatusOK, chatMessageResponse{
		Response: resp.Response,
	})
}
