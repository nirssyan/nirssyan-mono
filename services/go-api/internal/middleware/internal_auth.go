package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

type InternalAuthMiddleware struct {
	token string
}

func NewInternalAuthMiddleware(token string) *InternalAuthMiddleware {
	return &InternalAuthMiddleware{token: token}
}

func (m *InternalAuthMiddleware) Authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "missing authorization header", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" || parts[1] != m.token {
			log.Debug().Msg("Internal auth: invalid token")
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		onBehalfOf := r.Header.Get("X-On-Behalf-Of")
		if onBehalfOf == "" {
			http.Error(w, "missing X-On-Behalf-Of header", http.StatusBadRequest)
			return
		}

		userID, err := uuid.Parse(onBehalfOf)
		if err != nil {
			http.Error(w, "invalid X-On-Behalf-Of: must be a valid UUID", http.StatusBadRequest)
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
