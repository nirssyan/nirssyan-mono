package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/pkg/hmac"
)

var eventEmojis = map[string]string{
	"appStoreVersionAppVersionStateUpdated":       "🚀",
	"buildUploadStateUpdated":                     "📦",
	"buildBetaDetailExternalBuildStateUpdated":   "🧪",
	"betaFeedbackScreenshotSubmissionCreated":    "📸",
	"betaFeedbackCrashSubmissionCreated":         "💥",
	"webhookPingCreated":                         "🏓",
}

var eventTitles = map[string]string{
	"appStoreVersionAppVersionStateUpdated":       "App Version State Changed",
	"buildUploadStateUpdated":                     "Build Upload Status",
	"buildBetaDetailExternalBuildStateUpdated":   "TestFlight Build Status",
	"betaFeedbackScreenshotSubmissionCreated":    "TestFlight Screenshot Feedback",
	"betaFeedbackCrashSubmissionCreated":         "TestFlight Crash Report",
	"webhookPingCreated":                         "Webhook Ping",
}

type AppStoreService struct {
	cfg *config.Config
}

func NewAppStoreService(cfg *config.Config) *AppStoreService {
	return &AppStoreService{cfg: cfg}
}

func (s *AppStoreService) VerifySignature(payload []byte, signature string) error {
	return hmac.VerifyAppStoreSignature(payload, signature, s.cfg.AppStoreWebhookSecret)
}

func (s *AppStoreService) FormatTelegramMessage(payload models.AppStoreWebhookPayload) string {
	eventType := payload.Data.Type
	emoji := eventEmojis[eventType]
	if emoji == "" {
		emoji = "📱"
	}
	title := eventTitles[eventType]
	if title == "" {
		title = eventType
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("%s <b>App Store: %s</b>", emoji, title))
	lines = append(lines, "")

	attributes := payload.Data.Attributes
	if oldState, ok := attributes["oldState"].(string); ok {
		if newState, ok := attributes["newState"].(string); ok {
			lines = append(lines, fmt.Sprintf("📊 %s → %s", oldState, newState))
		}
	}

	for key, value := range attributes {
		if key != "oldState" && key != "newState" {
			lines = append(lines, fmt.Sprintf("• %s: <code>%v</code>", key, value))
		}
	}

	eventID := payload.Data.ID
	if len(eventID) > 8 {
		eventID = eventID[:8]
	}
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("<i>Event ID: %s...</i>", eventID))

	return strings.Join(lines, "\n")
}

func (s *AppStoreService) ProcessWebhook(ctx context.Context, payload models.AppStoreWebhookPayload) models.AppStoreWebhookProcessingResult {
	eventType := payload.Data.Type
	log.Info().Str("event_type", eventType).Msg("App Store webhook received")

	message := s.FormatTelegramMessage(payload)

	telegramCfg := TelegramConfig{
		BotToken: s.cfg.AppStoreTelegramBotToken,
		ChatID:   s.cfg.AppStoreTelegramChatID,
		ThreadID: s.cfg.AppStoreTelegramThreadID,
	}

	telegramSent := SendTelegramNotification(ctx, telegramCfg, message, false)

	return models.AppStoreWebhookProcessingResult{
		Success:      true,
		EventType:    eventType,
		TelegramSent: telegramSent,
	}
}
