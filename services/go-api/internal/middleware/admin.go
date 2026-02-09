package middleware

import (
	"net/http"

	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type AdminMiddleware struct {
	userRepo *repository.UserRepository
}

func NewAdminMiddleware(userRepo *repository.UserRepository) *AdminMiddleware {
	return &AdminMiddleware{userRepo: userRepo}
}

func (m *AdminMiddleware) RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, ok := GetUserID(r.Context())
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		isAdmin, err := m.userRepo.IsAdmin(r.Context(), userID)
		if err != nil {
			log.Error().Err(err).Str("user_id", userID.String()).Msg("Failed to check admin status")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if !isAdmin {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		next.ServeHTTP(w, r)
	})
}
