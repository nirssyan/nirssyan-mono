package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

type contextKey string

const UserIDKey contextKey = "user_id"
const UserEmailKey contextKey = "user_email"

type AuthMiddleware struct {
	jwtSecret []byte
}

func NewAuthMiddleware(jwtSecret string) *AuthMiddleware {
	return &AuthMiddleware{
		jwtSecret: []byte(jwtSecret),
	}
}

func (m *AuthMiddleware) Authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "missing authorization header", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			http.Error(w, "invalid authorization header format", http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]
		userID, email, err := m.validateToken(tokenString)
		if err != nil {
			log.Debug().Err(err).Msg("Token validation failed")
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, userID)
		if email != "" {
			ctx = context.WithValue(ctx, UserEmailKey, email)
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (m *AuthMiddleware) OptionalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			next.ServeHTTP(w, r)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
			if userID, email, err := m.validateToken(parts[1]); err == nil {
				ctx := context.WithValue(r.Context(), UserIDKey, userID)
				if email != "" {
					ctx = context.WithValue(ctx, UserEmailKey, email)
				}
				next.ServeHTTP(w, r.WithContext(ctx))
				return
			}
		}

		next.ServeHTTP(w, r)
	})
}

func (m *AuthMiddleware) validateToken(tokenString string) (uuid.UUID, string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return m.jwtSecret, nil
	})

	if err != nil {
		return uuid.Nil, "", err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return uuid.Nil, "", jwt.ErrSignatureInvalid
	}

	sub, ok := claims["sub"].(string)
	if !ok {
		return uuid.Nil, "", jwt.ErrSignatureInvalid
	}

	userID, err := uuid.Parse(sub)
	if err != nil {
		return uuid.Nil, "", err
	}

	email, _ := claims["email"].(string)

	return userID, email, nil
}

func GetUserID(ctx context.Context) (uuid.UUID, bool) {
	userID, ok := ctx.Value(UserIDKey).(uuid.UUID)
	return userID, ok
}

func GetUserEmail(ctx context.Context) string {
	email, _ := ctx.Value(UserEmailKey).(string)
	return email
}

// ValidateJWT validates a JWT token and returns the user ID
// This is used by WebSocket handler where we can't use middleware
func ValidateJWT(tokenString, jwtSecret string) (uuid.UUID, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(jwtSecret), nil
	})

	if err != nil {
		return uuid.Nil, err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return uuid.Nil, jwt.ErrSignatureInvalid
	}

	sub, ok := claims["sub"].(string)
	if !ok {
		return uuid.Nil, jwt.ErrSignatureInvalid
	}

	userID, err := uuid.Parse(sub)
	if err != nil {
		return uuid.Nil, err
	}

	return userID, nil
}
