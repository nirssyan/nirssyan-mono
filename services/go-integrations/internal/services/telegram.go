package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/rs/zerolog/log"
)

type TelegramConfig struct {
	BotToken string
	ChatID   string
	ThreadID int
}

type telegramPayload struct {
	ChatID              string `json:"chat_id"`
	Text                string `json:"text"`
	ParseMode           string `json:"parse_mode"`
	MessageThreadID     int    `json:"message_thread_id,omitempty"`
	DisableWebPreview   bool   `json:"disable_web_page_preview,omitempty"`
}

func SendTelegramNotification(ctx context.Context, cfg TelegramConfig, message string, disablePreview bool) bool {
	if cfg.BotToken == "" || cfg.ChatID == "" {
		log.Warn().Msg("Telegram credentials not configured")
		return false
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", cfg.BotToken)

	payload := telegramPayload{
		ChatID:            cfg.ChatID,
		Text:              message,
		ParseMode:         "HTML",
		DisableWebPreview: disablePreview,
	}

	if cfg.ThreadID > 0 {
		payload.MessageThreadID = cfg.ThreadID
	}

	body, err := json.Marshal(payload)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal Telegram payload")
		return false
	}

	client := &http.Client{Timeout: 30 * time.Second}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		log.Error().Err(err).Msg("Failed to create Telegram request")
		return false
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		log.Error().Err(err).Msg("Network error sending Telegram notification")
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		log.Info().Msg("Telegram notification sent successfully")
		return true
	}

	log.Error().
		Int("status_code", resp.StatusCode).
		Msg("Failed to send Telegram notification")
	return false
}
