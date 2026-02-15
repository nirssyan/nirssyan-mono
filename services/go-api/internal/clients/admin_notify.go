package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/rs/zerolog/log"
)

type AdminNotifyClient struct {
	botToken    string
	chatID      string
	environment string
	client      *http.Client
}

func NewAdminNotifyClient(botToken, chatID, environment string) *AdminNotifyClient {
	return &AdminNotifyClient{
		botToken:    botToken,
		chatID:      chatID,
		environment: environment,
		client:      &http.Client{Timeout: 30 * time.Second},
	}
}

func (c *AdminNotifyClient) getEnvPrefix() string {
	switch c.environment {
	case "development":
		return "[DEV] "
	case "production":
		return "[PROD] "
	default:
		return ""
	}
}

type NotifyFeedParams struct {
	Email        string
	FeedID       string
	FeedName     string
	FeedType     string
	Sources      []string
	Filters      []string
	Views        []string
	CurrentCount int
	Limit        int
}

func (c *AdminNotifyClient) NotifyNewFeed(ctx context.Context, threadID int, params NotifyFeedParams) {
	if c.botToken == "" || c.chatID == "" || threadID == 0 {
		return
	}

	sourcesText := strings.Join(params.Sources, ", ")
	if len(params.Sources) > 5 {
		sourcesText = strings.Join(params.Sources[:5], ", ") + fmt.Sprintf(" (+%d more)", len(params.Sources)-5)
	}

	filtersText := "—"
	if len(params.Filters) > 0 {
		filtersText = strings.Join(params.Filters, ", ")
		if len(params.Filters) > 3 {
			filtersText = strings.Join(params.Filters[:3], ", ") + fmt.Sprintf(" (+%d more)", len(params.Filters)-3)
		}
	}

	viewsText := "—"
	if len(params.Views) > 0 {
		viewsText = strings.Join(params.Views, ", ")
		if len(params.Views) > 3 {
			viewsText = strings.Join(params.Views[:3], ", ") + fmt.Sprintf(" (+%d more)", len(params.Views)-3)
		}
	}

	email := params.Email
	if email == "" {
		email = "N/A"
	}

	text := fmt.Sprintf(`%s📋 <b>Новая лента</b>

👤 <b>Email:</b> %s
📊 <b>Ленты:</b> %d/%d

🆔 <b>ID:</b> <code>%s</code>
📝 <b>Название:</b> %s
🔖 <b>Тип:</b> %s
📡 <b>Источники:</b> %s
🔍 <b>Фильтры:</b> %s
👁 <b>Вьюшки:</b> %s`,
		c.getEnvPrefix(),
		escapeHTML(email),
		params.CurrentCount+1, params.Limit,
		params.FeedID,
		escapeHTML(params.FeedName),
		params.FeedType,
		escapeHTML(sourcesText),
		escapeHTML(filtersText),
		escapeHTML(viewsText),
	)

	if err := c.sendMessage(ctx, threadID, text); err != nil {
		log.Warn().Err(err).Msg("Failed to send feed notification")
	} else {
		log.Info().Str("feed_name", params.FeedName).Msg("New feed notification sent")
	}
}

type NotifyUserParams struct {
	Email     string
	UserID    string
	CreatedAt *time.Time
}

func (c *AdminNotifyClient) NotifyNewUser(ctx context.Context, threadID int, params NotifyUserParams) {
	if c.botToken == "" || c.chatID == "" || threadID == 0 {
		return
	}

	email := params.Email
	if email == "" {
		email = "N/A"
	}

	createdAtStr := "N/A"
	if params.CreatedAt != nil {
		createdAtStr = params.CreatedAt.Format("2006-01-02 15:04")
	}

	text := fmt.Sprintf(`%s👤 <b>Новый пользователь</b>

📧 <b>Email:</b> %s
🆔 <b>ID:</b> <code>%s</code>
📅 <b>Дата:</b> %s`,
		c.getEnvPrefix(),
		escapeHTML(email),
		params.UserID,
		createdAtStr,
	)

	if err := c.sendMessage(ctx, threadID, text); err != nil {
		log.Warn().Err(err).Msg("Failed to send user notification")
	} else {
		log.Info().Str("email", params.Email).Msg("New user notification sent")
	}
}

func (c *AdminNotifyClient) NotifyReturningUser(ctx context.Context, threadID int, params NotifyUserParams) {
	if c.botToken == "" || c.chatID == "" || threadID == 0 {
		return
	}

	email := params.Email
	if email == "" {
		email = "N/A"
	}

	text := fmt.Sprintf(`%s🔄 <b>Пользователь вернулся</b>

📧 <b>Email:</b> %s
🆔 <b>ID:</b> <code>%s</code>`,
		c.getEnvPrefix(),
		escapeHTML(email),
		params.UserID,
	)

	if err := c.sendMessage(ctx, threadID, text); err != nil {
		log.Warn().Err(err).Msg("Failed to send returning user notification")
	} else {
		log.Info().Str("email", params.Email).Msg("Returning user notification sent")
	}
}

func (c *AdminNotifyClient) NotifyDeletedUser(ctx context.Context, threadID int, params NotifyUserParams) {
	if c.botToken == "" || c.chatID == "" || threadID == 0 {
		return
	}

	email := params.Email
	if email == "" {
		email = "N/A"
	}

	text := fmt.Sprintf(`%s🗑 <b>Пользователь удалён</b>

📧 <b>Email:</b> %s
🆔 <b>ID:</b> <code>%s</code>`,
		c.getEnvPrefix(),
		escapeHTML(email),
		params.UserID,
	)

	if err := c.sendMessage(ctx, threadID, text); err != nil {
		log.Warn().Err(err).Msg("Failed to send deleted user notification")
	} else {
		log.Info().Str("email", params.Email).Msg("Deleted user notification sent")
	}
}

func (c *AdminNotifyClient) sendMessage(ctx context.Context, threadID int, text string) error {
	if middleware.IsDryRunNotify(ctx) {
		preview := text
		if len(preview) > 100 {
			preview = preview[:100]
		}
		log.Info().Int("thread_id", threadID).Str("text_preview", preview).
			Msg("Telegram notification suppressed (dry-run)")
		return nil
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", c.botToken)

	payload := map[string]interface{}{
		"chat_id":           c.chatID,
		"message_thread_id": threadID,
		"text":              text,
		"parse_mode":        "HTML",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	return nil
}

func escapeHTML(text string) string {
	text = strings.ReplaceAll(text, "&", "&amp;")
	text = strings.ReplaceAll(text, "<", "&lt;")
	text = strings.ReplaceAll(text, ">", "&gt;")
	return text
}
