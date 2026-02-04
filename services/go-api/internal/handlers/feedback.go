package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type FeedbackHandler struct {
	feedbackRepo     *repository.FeedbackRepository
	telegramBotToken string
	telegramChatID   string
}

func NewFeedbackHandler(
	feedbackRepo *repository.FeedbackRepository,
	telegramBotToken string,
	telegramChatID string,
) *FeedbackHandler {
	return &FeedbackHandler{
		feedbackRepo:     feedbackRepo,
		telegramBotToken: telegramBotToken,
		telegramChatID:   telegramChatID,
	}
}

func (h *FeedbackHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/", h.SubmitFeedback)

	return r
}

type SubmitFeedbackRequest struct {
	Message  string  `json:"message"`
	Type     string  `json:"type"`
	Metadata *string `json:"metadata,omitempty"`
}

func (h *FeedbackHandler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req SubmitFeedbackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Message == "" {
		http.Error(w, "message is required", http.StatusBadRequest)
		return
	}

	feedback, err := h.feedbackRepo.Create(r.Context(), repository.CreateFeedbackParams{
		UserID:   userID,
		Message:  req.Message,
		Type:     req.Type,
		Metadata: req.Metadata,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create feedback")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if h.telegramBotToken != "" && h.telegramChatID != "" {
		go h.sendTelegramNotification(userID, req.Message, req.Type)
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":     feedback.ID,
		"status": "submitted",
	})
}

func (h *FeedbackHandler) sendTelegramNotification(userID uuid.UUID, message, feedbackType string) {
	text := fmt.Sprintf("📝 *New Feedback*\n\nUser: `%s`\nType: %s\n\n%s",
		userID.String(), feedbackType, message)

	body := map[string]interface{}{
		"chat_id":    h.telegramChatID,
		"text":       text,
		"parse_mode": "Markdown",
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal telegram message")
		return
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", h.telegramBotToken)
	resp, err := http.Post(url, "application/json", bytes.NewReader(jsonBody))
	if err != nil {
		log.Error().Err(err).Msg("Failed to send telegram notification")
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Warn().Int("status", resp.StatusCode).Msg("Telegram notification failed")
	}
}
