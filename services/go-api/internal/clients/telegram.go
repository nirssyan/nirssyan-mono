package clients

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type TelegramClient struct {
	nc       *nats.Conn
	botToken string
}

func NewTelegramClient(nc *nats.Conn, botToken string) *TelegramClient {
	return &TelegramClient{
		nc:       nc,
		botToken: botToken,
	}
}

type GetFileURLRequest struct {
	FileID string `json:"file_id"`
}

type GetFileURLResponse struct {
	URL   string `json:"url"`
	Error string `json:"error,omitempty"`
}

func (c *TelegramClient) GetFileURL(ctx context.Context, fileID string) (string, error) {
	if c.nc == nil {
		return c.getFileURLDirect(ctx, fileID)
	}

	req := GetFileURLRequest{FileID: fileID}
	data, err := json.Marshal(req)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	msg, err := c.nc.RequestWithContext(ctx, "telegram.get_file_url", data)
	if err != nil {
		return c.getFileURLDirect(ctx, fileID)
	}

	var resp GetFileURLResponse
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		return "", fmt.Errorf("unmarshal response: %w", err)
	}

	if resp.Error != "" {
		return "", fmt.Errorf("telegram error: %s", resp.Error)
	}

	return resp.URL, nil
}

type telegramAPIResponse struct {
	OK     bool `json:"ok"`
	Result struct {
		FileID       string `json:"file_id"`
		FileUniqueID string `json:"file_unique_id"`
		FileSize     int64  `json:"file_size"`
		FilePath     string `json:"file_path"`
	} `json:"result"`
	Description string `json:"description,omitempty"`
}

func (c *TelegramClient) getFileURLDirect(ctx context.Context, fileID string) (string, error) {
	if c.botToken == "" {
		return "", fmt.Errorf("bot token not configured")
	}

	apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/getFile?file_id=%s", c.botToken, fileID)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiURL, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("telegram api request: %w", err)
	}
	defer resp.Body.Close()

	var apiResp telegramAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return "", fmt.Errorf("decode response: %w", err)
	}

	if !apiResp.OK {
		return "", fmt.Errorf("telegram api error: %s", apiResp.Description)
	}

	if apiResp.Result.FilePath == "" {
		return "", fmt.Errorf("empty file_path in response")
	}

	fileURL := fmt.Sprintf("https://api.telegram.org/file/bot%s/%s", c.botToken, apiResp.Result.FilePath)
	return fileURL, nil
}

type GetFileRequest struct {
	FileID   string `json:"file_id"`
	FileType string `json:"file_type"`
	ChatID   int64  `json:"chat_id,omitempty"`
	MsgID    int    `json:"msg_id,omitempty"`
}

type GetFileResponse struct {
	Data     string `json:"data,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	Error    string `json:"error,omitempty"`
}

func (c *TelegramClient) GetFile(ctx context.Context, fileID, fileType string, chatID int64, msgID int) ([]byte, string, error) {
	if c.nc == nil {
		return nil, "", fmt.Errorf("NATS not connected")
	}

	req := GetFileRequest{
		FileID:   fileID,
		FileType: fileType,
		ChatID:   chatID,
		MsgID:    msgID,
	}

	data, err := json.Marshal(req)
	if err != nil {
		return nil, "", fmt.Errorf("marshal request: %w", err)
	}

	msg, err := c.nc.RequestWithContext(ctx, "telegram.get_file", data)
	if err != nil {
		return nil, "", fmt.Errorf("nats request: %w", err)
	}

	var resp GetFileResponse
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		return nil, "", fmt.Errorf("unmarshal response: %w", err)
	}

	if resp.Error != "" {
		return nil, "", fmt.Errorf("telegram error: %s", resp.Error)
	}

	fileData, err := base64.StdEncoding.DecodeString(resp.Data)
	if err != nil {
		return nil, "", fmt.Errorf("decode base64: %w", err)
	}

	return fileData, resp.MimeType, nil
}

type RefetchMessageRequest struct {
	ChatID    int64  `json:"chat_id"`
	MessageID int    `json:"message_id"`
	MediaType string `json:"media_type"`
}

type RefetchMessageResponse struct {
	FileID          string `json:"file_id,omitempty"`
	ActualMediaType string `json:"actual_media_type,omitempty"`
	Error           string `json:"error,omitempty"`
}

func (c *TelegramClient) RefetchMessage(ctx context.Context, chatID int64, messageID int, mediaType string) (string, string, error) {
	if c.nc == nil {
		return "", "", fmt.Errorf("NATS not connected")
	}

	req := RefetchMessageRequest{
		ChatID:    chatID,
		MessageID: messageID,
		MediaType: mediaType,
	}

	data, err := json.Marshal(req)
	if err != nil {
		return "", "", fmt.Errorf("marshal request: %w", err)
	}

	msg, err := c.nc.RequestWithContext(ctx, "telegram.refetch_message", data)
	if err != nil {
		return "", "", fmt.Errorf("nats request: %w", err)
	}

	var resp RefetchMessageResponse
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		return "", "", fmt.Errorf("unmarshal response: %w", err)
	}

	if resp.Error != "" {
		return "", "", fmt.Errorf("telegram error: %s", resp.Error)
	}

	actualType := resp.ActualMediaType
	if actualType == "" {
		actualType = mediaType
	}

	return resp.FileID, actualType, nil
}

type SendMessageRequest struct {
	ChatID string `json:"chat_id"`
	Text   string `json:"text"`
}

func (c *TelegramClient) SendMessage(ctx context.Context, chatID, text string) error {
	if c.botToken == "" {
		return fmt.Errorf("bot token not configured")
	}

	apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
		c.botToken, chatID, text)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, apiURL, nil)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return fmt.Errorf("telegram api request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("telegram api error: status %d", resp.StatusCode)
	}

	return nil
}

type TriggerSyncRequest struct{}

type TriggerSyncResponse struct {
	Status string `json:"status"`
	Error  string `json:"error,omitempty"`
}

func (c *TelegramClient) TriggerSync(ctx context.Context) error {
	if c.nc == nil {
		return fmt.Errorf("NATS not connected")
	}

	data, _ := json.Marshal(TriggerSyncRequest{})

	msg, err := c.nc.RequestWithContext(ctx, "telegram.trigger_sync", data)
	if err != nil {
		return fmt.Errorf("nats request: %w", err)
	}

	var resp TriggerSyncResponse
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		return fmt.Errorf("unmarshal response: %w", err)
	}

	if resp.Error != "" {
		return fmt.Errorf("sync error: %s", resp.Error)
	}

	log.Info().Msg("Telegram sync triggered")
	return nil
}
