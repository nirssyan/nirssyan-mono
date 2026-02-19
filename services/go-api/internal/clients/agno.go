package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/rs/zerolog/log"
)

type AgnoClient struct {
	baseURL    string
	httpClient *http.Client
}

func NewAgnoClient(baseURL string) *AgnoClient {
	return &AgnoClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

type agnoChatRequest struct {
	Message   string `json:"message"`
	UserID    string `json:"user_id"`
	SessionID string `json:"session_id,omitempty"`
}

type agnoChatResponse struct {
	Content string `json:"content"`
}

type ChatResponse struct {
	Response string `json:"response"`
}

func (c *AgnoClient) SendMessage(ctx context.Context, userID string, message string) (*ChatResponse, error) {
	reqBody := agnoChatRequest{
		Message:   message,
		UserID:    userID,
		SessionID: userID,
	}

	data, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := c.baseURL + "/v1/chat"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	log.Debug().
		Str("url", url).
		Str("user_id", userID).
		Msg("Sending message to Agno assistant")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("agno request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("agno returned %d: %s", resp.StatusCode, string(body))
	}

	var agnoResp agnoChatResponse
	if err := json.Unmarshal(body, &agnoResp); err != nil {
		return &ChatResponse{Response: string(body)}, nil
	}

	return &ChatResponse{Response: agnoResp.Content}, nil
}
