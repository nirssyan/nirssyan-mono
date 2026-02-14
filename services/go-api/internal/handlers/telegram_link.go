package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type TelegramLinkHandler struct {
	telegramUserRepo     *repository.TelegramUserRepository
	telegramLinkCodeRepo *repository.TelegramLinkCodeRepository
	botUsername          string
	linkExpiryMins       int
}

func NewTelegramLinkHandler(
	telegramUserRepo *repository.TelegramUserRepository,
	telegramLinkCodeRepo *repository.TelegramLinkCodeRepository,
	botUsername string,
	linkExpiryMins int,
) *TelegramLinkHandler {
	return &TelegramLinkHandler{
		telegramUserRepo:     telegramUserRepo,
		telegramLinkCodeRepo: telegramLinkCodeRepo,
		botUsername:          botUsername,
		linkExpiryMins:       linkExpiryMins,
	}
}

func (h *TelegramLinkHandler) AuthenticatedRoutes() chi.Router {
	r := chi.NewRouter()

	r.Get("/link-url", h.GetLinkURL)
	r.Get("/status", h.GetStatus)
	r.Delete("/unlink", h.Unlink)

	return r
}

type LinkURLResponse struct {
	URL string `json:"url"`
}

func (h *TelegramLinkHandler) GetLinkURL(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	expiresAt := time.Now().Add(time.Duration(h.linkExpiryMins) * time.Minute)
	linkCode, err := h.telegramLinkCodeRepo.Create(r.Context(), userID, expiresAt)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create telegram link code")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	url := fmt.Sprintf("https://t.me/%s?start=%s", h.botUsername, linkCode.Code)

	log.Info().
		Str("user_id", userID.String()).
		Str("code", linkCode.Code).
		Msg("Generated Telegram link URL")

	writeJSON(w, http.StatusOK, LinkURLResponse{URL: url})
}

type TelegramStatusResponse struct {
	Linked           bool    `json:"linked"`
	TelegramUsername *string `json:"telegram_username,omitempty"`
}

func (h *TelegramLinkHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	telegramUser, err := h.telegramUserRepo.GetByUserID(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get telegram user")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if telegramUser == nil {
		writeJSON(w, http.StatusOK, TelegramStatusResponse{
			Linked: false,
		})
		return
	}

	writeJSON(w, http.StatusOK, TelegramStatusResponse{
		Linked:           true,
		TelegramUsername: telegramUser.Username,
	})
}

type TelegramUnlinkResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func (h *TelegramLinkHandler) Unlink(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	wasUnlinked, err := h.telegramUserRepo.UnlinkByUserID(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to unlink telegram")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if wasUnlinked {
		log.Info().Str("user_id", userID.String()).Msg("Unlinked Telegram account")
		writeJSON(w, http.StatusOK, TelegramUnlinkResponse{
			Success: true,
			Message: "Telegram account unlinked successfully",
		})
	} else {
		writeJSON(w, http.StatusOK, TelegramUnlinkResponse{
			Success: true,
			Message: "No linked Telegram account found",
		})
	}
}
