package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/rs/zerolog/log"
)

type SourceValidationHandler struct {
	validationClient *clients.ValidationClient
}

func NewSourceValidationHandler(validationClient *clients.ValidationClient) *SourceValidationHandler {
	return &SourceValidationHandler{validationClient: validationClient}
}

func (h *SourceValidationHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/validate", h.ValidateSource)

	return r
}

type ValidateSourceRequest struct {
	URL         string `json:"url"`
	Source      string `json:"source"`
	Lightweight bool   `json:"lightweight,omitempty"`
}

type ValidateSourceResponse struct {
	IsValid      bool    `json:"is_valid"`
	SourceType   *string `json:"source_type,omitempty"`
	DetectedType *string `json:"detected_type,omitempty"`
	ShortName    *string `json:"short_name,omitempty"`
}

func (h *SourceValidationHandler) ValidateSource(w http.ResponseWriter, r *http.Request) {
	var req ValidateSourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Warn().Err(err).Msg("Invalid request body for source validation")
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Accept both "url" and "source" fields for compatibility
	source := req.URL
	if source == "" {
		source = req.Source
	}

	if source == "" {
		log.Warn().Msg("Empty source in source validation request")
		http.Error(w, "source is required", http.StatusBadRequest)
		return
	}

	// Extract short name and detect type
	shortName, sourceType := extractSourceInfo(source)

	// For validation, convert @username to full URL
	validationURL := source
	if strings.HasPrefix(source, "@") {
		validationURL = "https://t.me/" + strings.TrimPrefix(source, "@")
	}

	result, err := h.validationClient.ValidateSource(r.Context(), validationURL, strings.ToLower(sourceType), req.Lightweight)
	if err != nil {
		log.Error().Err(err).Str("source", source).Msg("Source validation failed")
		writeJSON(w, http.StatusOK, ValidateSourceResponse{
			IsValid: false,
		})
		return
	}

	if !result.Valid {
		writeJSON(w, http.StatusOK, ValidateSourceResponse{
			IsValid: false,
		})
		return
	}

	// Determine detected_type based on validation result
	detectedType := result.SourceType
	if detectedType == nil {
		dt := strings.ToUpper(sourceType)
		detectedType = &dt
	}

	writeJSON(w, http.StatusOK, ValidateSourceResponse{
		IsValid:      true,
		SourceType:   &sourceType,
		DetectedType: detectedType,
		ShortName:    &shortName,
	})
}

func extractSourceInfo(source string) (shortName string, sourceType string) {
	source = strings.TrimSpace(source)

	// Check for @username format
	if strings.HasPrefix(source, "@") {
		username := strings.TrimPrefix(source, "@")
		return strings.ToLower(username), "TELEGRAM"
	}

	// Check for t.me or telegram.me URLs
	lowerSource := strings.ToLower(source)
	if strings.Contains(lowerSource, "t.me/") || strings.Contains(lowerSource, "telegram.me/") {
		// Extract username from URL
		var username string
		if idx := strings.Index(lowerSource, "t.me/"); idx != -1 {
			username = source[idx+5:]
		} else if idx := strings.Index(lowerSource, "telegram.me/"); idx != -1 {
			username = source[idx+12:]
		}
		// Remove trailing path parts
		if idx := strings.Index(username, "/"); idx != -1 {
			username = username[:idx]
		}
		if idx := strings.Index(username, "?"); idx != -1 {
			username = username[:idx]
		}
		return strings.ToLower(username), "TELEGRAM"
	}

	// For websites, extract domain
	domain := extractDomain(source)
	if domain != "" {
		return domain, "WEBSITE"
	}

	return source, "WEBSITE"
}

func extractDomain(source string) string {
	// Add scheme if missing
	if !strings.HasPrefix(source, "http://") && !strings.HasPrefix(source, "https://") {
		source = "https://" + source
	}

	// Simple domain extraction
	source = strings.TrimPrefix(source, "https://")
	source = strings.TrimPrefix(source, "http://")

	// Remove path
	if idx := strings.Index(source, "/"); idx != -1 {
		source = source[:idx]
	}

	// Remove port
	if idx := strings.Index(source, ":"); idx != -1 {
		source = source[:idx]
	}

	return strings.ToLower(source)
}
