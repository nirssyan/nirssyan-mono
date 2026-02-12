package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-api/internal/config"
)

type AuthHandler struct {
	cfg *config.Config
}

func NewAuthHandler(cfg *config.Config) *AuthHandler {
	return &AuthHandler{cfg: cfg}
}

func (h *AuthHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/demo-login", h.DemoLogin)
	return r
}

type demoLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type demoUser struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type authResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresIn    int       `json:"expires_in"`
	TokenType    string    `json:"token_type"`
	User         *demoUser `json:"user"`
}

type demoClaims struct {
	jwt.RegisteredClaims
	UserID string `json:"uid"`
	Email  string `json:"email"`
}

func (h *AuthHandler) DemoLogin(w http.ResponseWriter, r *http.Request) {
	if !h.cfg.DemoModeEnabled {
		http.NotFound(w, r)
		return
	}

	var req demoLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "email is required"})
		return
	}

	if !strings.EqualFold(req.Email, h.cfg.DemoAccountEmail) || (req.Password != "" && req.Password != h.cfg.DemoAccountPassword) {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "invalid demo credentials"})
		return
	}

	if h.cfg.DemoAccountUserID == "" {
		log.Warn().Msg("Demo account not fully configured")
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "demo account not configured"})
		return
	}

	now := time.Now()
	expiresIn := 3600
	claims := demoClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "auth-service",
			Subject:   h.cfg.DemoAccountUserID,
			Audience:  jwt.ClaimStrings{"makefeed-api"},
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(expiresIn) * time.Second)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.New().String(),
		},
		UserID: h.cfg.DemoAccountUserID,
		Email:  h.cfg.DemoAccountEmail,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	accessToken, err := token.SignedString([]byte(h.cfg.JWTSecret))
	if err != nil {
		log.Error().Err(err).Msg("Demo login: failed to sign JWT")
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}

	refreshBytes := make([]byte, 32)
	if _, err := rand.Read(refreshBytes); err != nil {
		log.Error().Err(err).Msg("Demo login: failed to generate refresh token")
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	refreshToken := base64.URLEncoding.EncodeToString(refreshBytes)

	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    expiresIn,
		TokenType:    "bearer",
		User: &demoUser{
			ID:    h.cfg.DemoAccountUserID,
			Email: h.cfg.DemoAccountEmail,
		},
	})
}
