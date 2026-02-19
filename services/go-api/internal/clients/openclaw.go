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

type OpenClawClient struct {
	baseURL    string
	token      string
	httpClient *http.Client
}

func NewOpenClawClient(baseURL, token string) *OpenClawClient {
	return &OpenClawClient{
		baseURL: baseURL,
		token:   token,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

type openClawRequest struct {
	Message    string `json:"message"`
	AgentID    string `json:"agentId"`
	SessionKey string `json:"sessionKey"`
	Deliver    bool   `json:"deliver"`
}

type ChatResponse struct {
	Response string `json:"response"`
}

func (c *OpenClawClient) SendMessage(ctx context.Context, userID string, message string) (*ChatResponse, error) {
	reqBody := openClawRequest{
		Message:    message,
		AgentID:    "main",
		SessionKey: "user:" + userID,
		Deliver:    false,
	}

	data, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := c.baseURL + "/hooks/agent"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.token)

	log.Debug().
		Str("url", url).
		Str("session_key", reqBody.SessionKey).
		Msg("Sending message to OpenClaw")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("openclaw request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openclaw returned %d: %s", resp.StatusCode, string(body))
	}

	var chatResp ChatResponse
	if err := json.Unmarshal(body, &chatResp); err != nil {
		return &ChatResponse{Response: string(body)}, nil
	}

	return &chatResp, nil
}
