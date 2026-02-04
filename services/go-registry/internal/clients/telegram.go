package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
	"github.com/shopspring/decimal"
)

// TelegramClient sends notifications via Telegram Bot API
type TelegramClient struct {
	botToken string
	chatID   string
	threadID int
	client   *http.Client
}

func NewTelegramClient(botToken, chatID string, threadID int) *TelegramClient {
	return &TelegramClient{
		botToken: botToken,
		chatID:   chatID,
		threadID: threadID,
		client:   &http.Client{Timeout: 30 * time.Second},
	}
}

// NotifyNewModels sends notification about new models
func (c *TelegramClient) NotifyNewModels(ctx context.Context, models []ParsedModel) error {
	if len(models) == 0 {
		return nil
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("🆕 <b>Новые модели LLM</b> (%d)\n\n", len(models)))

	for i, model := range models {
		if i >= 20 {
			sb.WriteString(fmt.Sprintf("\n<i>... и ещё %d моделей</i>", len(models)-20))
			break
		}

		pricePrompt := formatPrice(model.PricePrompt)
		priceCompletion := formatPrice(model.PriceCompletion)

		sb.WriteString(fmt.Sprintf("• <code>%s</code>\n", model.ModelID))
		sb.WriteString(fmt.Sprintf("  💰 $%s/$%s per 1M tokens\n\n", pricePrompt, priceCompletion))
	}

	return c.sendMessage(ctx, sb.String())
}

// PriceChange represents a model price change
type PriceChange struct {
	ModelID                 string
	Name                    string
	PrevPricePrompt         decimal.Decimal
	PrevPriceCompletion     decimal.Decimal
	NewPricePrompt          decimal.Decimal
	NewPriceCompletion      decimal.Decimal
	ChangePercentPrompt     *float64
	ChangePercentCompletion *float64
}

// NotifyPriceChanges sends notification about price changes
func (c *TelegramClient) NotifyPriceChanges(ctx context.Context, changes []PriceChange) error {
	if len(changes) == 0 {
		return nil
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("💰 <b>Изменение цен LLM</b> (%d)\n\n", len(changes)))

	for i, change := range changes {
		if i >= 20 {
			sb.WriteString(fmt.Sprintf("\n<i>... и ещё %d изменений</i>", len(changes)-20))
			break
		}

		sb.WriteString(fmt.Sprintf("• <code>%s</code>\n", change.ModelID))

		if !change.PrevPricePrompt.Equal(change.NewPricePrompt) {
			percentStr := formatPercentChange(change.ChangePercentPrompt)
			sb.WriteString(fmt.Sprintf("  prompt: %s → %s <b>%s</b>\n",
				formatRawPrice(change.PrevPricePrompt),
				formatRawPrice(change.NewPricePrompt),
				percentStr))
		}

		if !change.PrevPriceCompletion.Equal(change.NewPriceCompletion) {
			percentStr := formatPercentChange(change.ChangePercentCompletion)
			sb.WriteString(fmt.Sprintf("  completion: %s → %s <b>%s</b>\n",
				formatRawPrice(change.PrevPriceCompletion),
				formatRawPrice(change.NewPriceCompletion),
				percentStr))
		}

		sb.WriteString("\n")
	}

	return c.sendMessage(ctx, sb.String())
}

func (c *TelegramClient) sendMessage(ctx context.Context, text string) error {
	if c.botToken == "" {
		log.Warn().Msg("Telegram bot token not configured, skipping notification")
		return nil
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", c.botToken)

	payload := map[string]interface{}{
		"chat_id":           c.chatID,
		"message_thread_id": c.threadID,
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

	log.Info().Msg("Telegram notification sent successfully")
	return nil
}

func formatPrice(price decimal.Decimal) string {
	pricePerMillion := price.Mul(decimal.NewFromInt(1_000_000))
	f, _ := pricePerMillion.Float64()

	if f < 0.01 {
		return fmt.Sprintf("%.4f", f)
	} else if f < 1 {
		return fmt.Sprintf("%.3f", f)
	}
	return fmt.Sprintf("%.2f", f)
}

func formatRawPrice(price decimal.Decimal) string {
	if price.IsZero() {
		return "0"
	}
	f, _ := price.Float64()
	if f < 1e-10 {
		return fmt.Sprintf("%.2e", f)
	} else if f < 1e-6 {
		return strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.10f", f), "0"), ".")
	} else if f < 0.01 {
		return strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.8f", f), "0"), ".")
	}
	return strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.6f", f), "0"), ".")
}

func formatPercentChange(percent *float64) string {
	if percent == nil {
		return "(new)"
	}
	sign := ""
	if *percent > 0 {
		sign = "+"
	}
	return fmt.Sprintf("(%s%.4f%%)", sign, *percent)
}
