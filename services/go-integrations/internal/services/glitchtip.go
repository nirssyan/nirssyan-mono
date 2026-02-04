package services

import (
	"context"
	"fmt"
	"html"
	"strings"
	"unicode"

	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
)

var fieldEmojis = map[string]string{
	"Project":     "🏷️",
	"Environment": "🌍",
	"Release":     "📦",
	"Level":       "📊",
	"Count":       "🔢",
}

type GlitchTipService struct {
	cfg *config.Config
}

func NewGlitchTipService(cfg *config.Config) *GlitchTipService {
	return &GlitchTipService{cfg: cfg}
}

func (s *GlitchTipService) extractIssueID(titleLink string) string {
	if titleLink == "" {
		return ""
	}
	parts := strings.Split(strings.TrimRight(titleLink, "/"), "/")
	if len(parts) > 0 {
		last := parts[len(parts)-1]
		if isNumeric(last) {
			return last
		}
	}
	return ""
}

func isNumeric(s string) bool {
	for _, r := range s {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return len(s) > 0
}

func (s *GlitchTipService) FormatTelegramMessage(payload models.GlitchTipWebhookPayload) string {
	if len(payload.Attachments) == 0 {
		return "🔴 <b>GlitchTip Alert</b>\n\n⚠️ Empty alert (no error details)"
	}

	attachment := payload.Attachments[0]
	issueID := s.extractIssueID(attachment.TitleLink)

	var header string
	if issueID != "" {
		header = fmt.Sprintf("🔴 <b>GlitchTip Alert #%s</b>", issueID)
	} else {
		header = "🔴 <b>GlitchTip Alert</b>"
	}

	var lines []string
	lines = append(lines, header, "")

	if attachment.Title != "" {
		lines = append(lines, fmt.Sprintf("⚠️ <b>Error:</b> %s", html.EscapeString(attachment.Title)))
	}

	if attachment.Text != "" {
		lines = append(lines, fmt.Sprintf("📍 <code>%s</code>", html.EscapeString(attachment.Text)))
	}

	lines = append(lines, "")

	for _, field := range attachment.Fields {
		emoji := fieldEmojis[field.Title]
		if emoji == "" {
			emoji = "•"
		}
		lines = append(lines, fmt.Sprintf("%s %s: %s", emoji, field.Title, html.EscapeString(field.Value)))
	}

	if attachment.TitleLink != "" {
		lines = append(lines, "")
		lines = append(lines, fmt.Sprintf(`🔗 <a href="%s">View in GlitchTip</a>`, attachment.TitleLink))
	}

	return strings.Join(lines, "\n")
}

func (s *GlitchTipService) ProcessWebhook(ctx context.Context, payload models.GlitchTipWebhookPayload) models.GlitchTipWebhookProcessingResult {
	var errorTitle string
	if len(payload.Attachments) > 0 {
		errorTitle = payload.Attachments[0].Title
	}
	log.Info().Str("error_title", errorTitle).Msg("GlitchTip webhook received")

	message := s.FormatTelegramMessage(payload)

	telegramCfg := TelegramConfig{
		BotToken: s.cfg.SentryTelegramBotToken,
		ChatID:   s.cfg.SentryTelegramChatID,
		ThreadID: s.cfg.SentryTelegramThreadID,
	}

	telegramSent := SendTelegramNotification(ctx, telegramCfg, message, true)

	return models.GlitchTipWebhookProcessingResult{
		Success:      true,
		ErrorTitle:   errorTitle,
		TelegramSent: telegramSent,
	}
}
