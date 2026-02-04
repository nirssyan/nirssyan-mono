package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type UserHandler struct {
	userRepo     *repository.UserRepository
	adminNotify  *clients.AdminNotifyClient
	userThreadID int
}

func NewUserHandler(userRepo *repository.UserRepository, adminNotify *clients.AdminNotifyClient, userThreadID int) *UserHandler {
	return &UserHandler{
		userRepo:     userRepo,
		adminNotify:  adminNotify,
		userThreadID: userThreadID,
	}
}

func (h *UserHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Delete("/me", h.DeleteMe)
	r.Post("/heartbeat", h.Heartbeat)

	return r
}

func (h *UserHandler) AdminRoutes() chi.Router {
	r := chi.NewRouter()

	r.Delete("/{target_user_id}", h.AdminDeleteUser)

	return r
}

func (h *UserHandler) DeleteMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	user, _ := h.userRepo.GetByID(r.Context(), userID)
	email := ""
	if user != nil && user.Email != nil {
		email = *user.Email
	}

	result, err := h.userRepo.Delete(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("Failed to delete user")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if h.adminNotify != nil {
		h.adminNotify.NotifyDeletedUser(r.Context(), h.userThreadID, clients.NotifyUserParams{
			Email:  email,
			UserID: userID.String(),
		})
	}

	log.Info().Str("user_id", userID.String()).Msg("User deleted")
	writeJSON(w, http.StatusOK, result)
}

func (h *UserHandler) Heartbeat(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	reactivated, err := h.userRepo.Reactivate(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("Failed to reactivate user")
		writeJSON(w, http.StatusOK, map[string]bool{"reactivated": false})
		return
	}

	if reactivated && h.adminNotify != nil {
		user, _ := h.userRepo.GetByID(r.Context(), userID)
		email := ""
		if user != nil && user.Email != nil {
			email = *user.Email
		}
		h.adminNotify.NotifyReturningUser(r.Context(), h.userThreadID, clients.NotifyUserParams{
			Email:  email,
			UserID: userID.String(),
		})
		log.Info().Str("user_id", userID.String()).Msg("User reactivated after deletion")
	}

	writeJSON(w, http.StatusOK, map[string]bool{"reactivated": reactivated})
}

func (h *UserHandler) AdminDeleteUser(w http.ResponseWriter, r *http.Request) {
	adminID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	isAdmin, err := h.userRepo.IsAdmin(r.Context(), adminID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check admin status")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !isAdmin {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	targetUserIDStr := chi.URLParam(r, "target_user_id")
	targetUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		http.Error(w, "invalid user_id", http.StatusBadRequest)
		return
	}

	user, _ := h.userRepo.GetByID(r.Context(), targetUserID)
	email := ""
	if user != nil && user.Email != nil {
		email = *user.Email
	}

	result, err := h.userRepo.Delete(r.Context(), targetUserID)
	if err != nil {
		log.Error().Err(err).Str("target_user_id", targetUserID.String()).Msg("Failed to admin delete user")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if h.adminNotify != nil {
		h.adminNotify.NotifyDeletedUser(r.Context(), h.userThreadID, clients.NotifyUserParams{
			Email:  email,
			UserID: targetUserID.String(),
		})
	}

	log.Info().
		Str("admin_id", adminID.String()).
		Str("target_user_id", targetUserID.String()).
		Msg("User deleted by admin")

	writeJSON(w, http.StatusOK, result)
}
