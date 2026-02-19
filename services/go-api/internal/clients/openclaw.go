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

type chatCompletionMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatCompletionRequest struct {
	Model    string                  `json:"model"`
	Messages []chatCompletionMessage `json:"messages"`
}

type chatCompletionChoice struct {
	Message chatCompletionMessage `json:"message"`
}

type chatCompletionResponse struct {
	Choices []chatCompletionChoice `json:"choices"`
}

type ChatResponse struct {
	Response string `json:"response"`
}

func (c *OpenClawClient) SendMessage(ctx context.Context, userID string, message string) (*ChatResponse, error) {
	reqBody := chatCompletionRequest{
		Model: "openclaw",
		Messages: []chatCompletionMessage{
			{Role: "user", Content: message},
		},
	}

	data, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := c.baseURL + "/v1/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("x-openclaw-session-key", "user:"+userID)

	log.Debug().
		Str("url", url).
		Str("session_key", "user:"+userID).
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

	var completionResp chatCompletionResponse
	if err := json.Unmarshal(body, &completionResp); err != nil {
		return &ChatResponse{Response: string(body)}, nil
	}

	if len(completionResp.Choices) == 0 {
		return &ChatResponse{Response: ""}, nil
	}

	return &ChatResponse{Response: completionResp.Choices[0].Message.Content}, nil
}
