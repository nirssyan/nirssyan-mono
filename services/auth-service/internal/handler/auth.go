package handler

import (
	"encoding/json"
	"errors"
	"net"
	"net/http"

	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/model"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/service"
	"github.com/rs/zerolog"
)

type AuthHandler struct {
	authService *service.AuthService
	logger      zerolog.Logger
}

func NewAuthHandler(authService *service.AuthService, logger zerolog.Logger) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		logger:      logger,
	}
}

func (h *AuthHandler) Google(w http.ResponseWriter, r *http.Request) {
	var req model.GoogleAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.IDToken == "" {
		h.writeError(w, http.StatusBadRequest, "missing_token", "id_token is required")
		return
	}

	deviceInfo := getDeviceInfo(r)
	ipAddress := parseIP(getClientIP(r))

	resp, err := h.authService.AuthenticateGoogle(r.Context(), req.IDToken, deviceInfo, ipAddress)
	if err != nil {
		h.logger.Error().Err(err).Msg("google authentication failed")
		if errors.Is(err, service.ErrInvalidGoogleToken) {
			h.writeError(w, http.StatusUnauthorized, "invalid_token", "Invalid Google ID token")
			return
		}
		h.writeError(w, http.StatusInternalServerError, "server_error", "Authentication failed")
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Apple(w http.ResponseWriter, r *http.Request) {
	var req model.AppleAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.IDToken == "" {
		h.writeError(w, http.StatusBadRequest, "missing_token", "id_token is required")
		return
	}

	deviceInfo := getDeviceInfo(r)
	ipAddress := parseIP(getClientIP(r))

	resp, err := h.authService.AuthenticateApple(r.Context(), req.IDToken, deviceInfo, ipAddress)
	if err != nil {
		h.logger.Error().Err(err).Msg("apple authentication failed")
		if errors.Is(err, service.ErrInvalidAppleToken) {
			h.writeError(w, http.StatusUnauthorized, "invalid_token", "Invalid Apple ID token")
			return
		}
		h.writeError(w, http.StatusInternalServerError, "server_error", "Authentication failed")
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) MagicLink(w http.ResponseWriter, r *http.Request) {
	var req model.MagicLinkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.Email == "" {
		h.writeError(w, http.StatusBadRequest, "missing_email", "email is required")
		return
	}

	if err := h.authService.SendMagicLink(r.Context(), req.Email); err != nil {
		h.logger.Error().Err(err).Str("email", req.Email).Msg("failed to send magic link")
		h.writeError(w, http.StatusInternalServerError, "server_error", "Failed to send magic link")
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]string{"message": "Magic link sent"})
}

func (h *AuthHandler) Verify(w http.ResponseWriter, r *http.Request) {
	var req model.VerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.Token == "" {
		h.writeError(w, http.StatusBadRequest, "missing_token", "token is required")
		return
	}

	deviceInfo := getDeviceInfo(r)
	ipAddress := parseIP(getClientIP(r))

	resp, err := h.authService.VerifyMagicLink(r.Context(), req.Token, deviceInfo, ipAddress)
	if err != nil {
		h.logger.Error().Err(err).Msg("magic link verification failed")

		switch {
		case errors.Is(err, service.ErrInvalidMagicLink):
			h.writeError(w, http.StatusUnauthorized, "invalid_token", "Invalid magic link")
		case errors.Is(err, service.ErrMagicLinkUsed):
			h.writeError(w, http.StatusUnauthorized, "token_used", "Magic link already used")
		case errors.Is(err, service.ErrMagicLinkExpired):
			h.writeError(w, http.StatusUnauthorized, "token_expired", "Magic link expired")
		default:
			h.writeError(w, http.StatusInternalServerError, "server_error", "Verification failed")
		}
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req model.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.RefreshToken == "" {
		h.writeError(w, http.StatusBadRequest, "missing_token", "refresh_token is required")
		return
	}

	deviceInfo := getDeviceInfo(r)
	ipAddress := parseIP(getClientIP(r))

	resp, err := h.authService.RefreshTokens(r.Context(), req.RefreshToken, deviceInfo, ipAddress)
	if err != nil {
		h.logger.Error().Err(err).Msg("token refresh failed")

		switch {
		case errors.Is(err, service.ErrTokenReuse):
			h.writeError(w, http.StatusUnauthorized, "token_reuse", "Security violation: token reused")
		case errors.Is(err, service.ErrTokenExpired):
			h.writeError(w, http.StatusUnauthorized, "token_expired", "Refresh token expired")
		case errors.Is(err, service.ErrFamilyRevoked):
			h.writeError(w, http.StatusUnauthorized, "session_revoked", "Session has been revoked")
		case errors.Is(err, service.ErrInvalidToken):
			h.writeError(w, http.StatusUnauthorized, "invalid_token", "Invalid refresh token")
		default:
			h.writeError(w, http.StatusInternalServerError, "server_error", "Token refresh failed")
		}
		return
	}

	h.writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var req model.LogoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body")
		return
	}

	if req.RefreshToken == "" {
		h.writeError(w, http.StatusBadRequest, "missing_token", "refresh_token is required")
		return
	}

	if err := h.authService.Logout(r.Context(), req.RefreshToken); err != nil {
		h.logger.Error().Err(err).Msg("logout failed")
		h.writeError(w, http.StatusInternalServerError, "server_error", "Logout failed")
		return
	}

	h.writeJSON(w, http.StatusOK, map[string]string{"message": "Logged out successfully"})
}

func (h *AuthHandler) writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *AuthHandler) writeError(w http.ResponseWriter, status int, errorCode, message string) {
	h.writeJSON(w, status, model.ErrorResponse{
		Error:   errorCode,
		Message: message,
	})
}

func getClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return xff
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	return r.RemoteAddr
}

func getDeviceInfo(r *http.Request) *string {
	ua := r.Header.Get("User-Agent")
	if ua == "" {
		return nil
	}
	return &ua
}

func parseIP(addr string) net.IP {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return net.ParseIP(addr)
	}
	return net.ParseIP(host)
}
