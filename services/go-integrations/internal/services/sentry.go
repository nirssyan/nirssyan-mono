package services

import (
	"context"
	"fmt"
	"html"
	"strings"

	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
)

var actionEmojis = map[string]string{
	"created":    "🔴",
	"resolved":   "✅",
	"assigned":   "👤",
	"archived":   "📦",
	"unresolved": "🔄",
}

var actionTitles = map[string]string{
	"created":    "New Issue Created",
	"resolved":   "Issue Resolved",
	"assigned":   "Issue Assigned",
	"archived":   "Issue Archived",
	"unresolved": "Issue Reopened",
}

var levelEmojis = map[string]string{
	"fatal":   "💀",
	"error":   "🔴",
	"warning": "🟡",
	"info":    "🔵",
	"debug":   "⚪",
}

type SentryService struct {
	cfg *config.Config
}

func NewSentryService(cfg *config.Config) *SentryService {
	return &SentryService{cfg: cfg}
}

func (s *SentryService) FormatTelegramMessage(payload models.SentryWebhookPayload) string {
	action := payload.Action
	issue := payload.Data.Issue

	actionEmoji := actionEmojis[action]
	if actionEmoji == "" {
		actionEmoji = "📌"
	}
	actionTitle := actionTitles[action]
	if actionTitle == "" {
		actionTitle = strings.Title(action)
	}
	levelEmoji := levelEmojis[issue.Level]
	if levelEmoji == "" {
		levelEmoji = "🔴"
	}

	emoji := levelEmoji
	if action != "created" {
		emoji = actionEmoji
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("%s <b>Sentry: %s</b>", emoji, actionTitle))
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("<b>%s</b>: %s", issue.ShortID, html.EscapeString(issue.Title)))

	if issue.Metadata != nil && issue.Metadata.Type != "" {
		errorInfo := issue.Metadata.Type
		if issue.Metadata.Value != "" {
			errorInfo += " - " + truncate(issue.Metadata.Value, 100)
		}
		lines = append(lines, fmt.Sprintf("⚠️ <code>%s</code>", html.EscapeString(errorInfo)))
	}

	if issue.Culprit != "" {
		lines = append(lines, fmt.Sprintf("📍 <code>%s</code>", html.EscapeString(issue.Culprit)))
	}

	var statsParts []string
	if issue.Count != "" {
		statsParts = append(statsParts, fmt.Sprintf("Events: %s", issue.Count))
	}
	if issue.UserCount > 0 {
		statsParts = append(statsParts, fmt.Sprintf("Users: %d", issue.UserCount))
	}
	if len(statsParts) > 0 {
		lines = append(lines, fmt.Sprintf("📊 %s", strings.Join(statsParts, " | ")))
	}

	link := issue.Permalink
	if link == "" {
		link = issue.WebURL
	}
	if link != "" {
		lines = append(lines, fmt.Sprintf(`🔗 <a href="%s">View in Sentry</a>`, link))
	}

	var footerParts []string
	footerParts = append(footerParts, fmt.Sprintf("Project: %s", issue.Project.Name))
	if issue.Level != "" {
		footerParts = append(footerParts, fmt.Sprintf("Level: %s", issue.Level))
	}
	if issue.Priority != "" {
		footerParts = append(footerParts, fmt.Sprintf("Priority: %s", issue.Priority))
	}
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("<i>%s</i>", strings.Join(footerParts, " | ")))

	if payload.Actor != nil && (action == "assigned" || action == "resolved") {
		actorName := payload.Actor.Name
		if actorName == "" {
			actorName = payload.Actor.ID
		}
		if actorName == "" {
			actorName = "Unknown"
		}
		lines = append(lines, fmt.Sprintf("<i>By: %s</i>", html.EscapeString(actorName)))
	}

	return strings.Join(lines, "\n")
}

func (s *SentryService) ProcessWebhook(ctx context.Context, payload models.SentryWebhookPayload) models.SentryWebhookProcessingResult {
	action := payload.Action
	issueID := payload.Data.Issue.ShortID
	log.Info().Str("action", action).Str("issue_id", issueID).Msg("Sentry webhook received")

	message := s.FormatTelegramMessage(payload)

	telegramCfg := TelegramConfig{
		BotToken: s.cfg.SentryTelegramBotToken,
		ChatID:   s.cfg.SentryTelegramChatID,
		ThreadID: s.cfg.SentryTelegramThreadID,
	}

	telegramSent := SendTelegramNotification(ctx, telegramCfg, message, true)

	return models.SentryWebhookProcessingResult{
		Success:      true,
		Action:       action,
		IssueID:      issueID,
		TelegramSent: telegramSent,
	}
}

func truncate(text string, maxLen int) string {
	if len(text) <= maxLen {
		return text
	}
	return text[:maxLen-3] + "..."
}
