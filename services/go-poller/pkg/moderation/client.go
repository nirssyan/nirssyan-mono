package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/rs/zerolog/log"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

type CheckRequest struct {
	ContentID   string     `json:"content_id"`
	SourceType  SourceType `json:"source_type"`
	SourceURL   string     `json:"source_url"`
	Title       string     `json:"title,omitempty"`
	Text        string     `json:"text"`
	PublishedAt *time.Time `json:"published_at,omitempty"`
}

type CheckResponse struct {
	Action       Action     `json:"action"`
	Labels       []Label    `json:"labels"`
	BlockReasons []string   `json:"block_reasons"`
	CheckedAt    time.Time  `json:"checked_at"`
}

type SourceType string

const (
	SourceTypeRSS      SourceType = "RSS"
	SourceTypeHTML     SourceType = "HTML"
	SourceTypeTelegram SourceType = "TELEGRAM"
)

type Action string

const (
	ActionAllow Action = "ALLOW"
	ActionBlock Action = "BLOCK"
	ActionFlag  Action = "FLAG"
)

type Label string

const (
	LabelSafe       Label = "SAFE"
	LabelSpam       Label = "SPAM"
	LabelAdult      Label = "ADULT"
	LabelViolence   Label = "VIOLENCE"
	LabelHate       Label = "HATE"
	LabelPolitical  Label = "POLITICAL"
	LabelPromotion  Label = "PROMOTION"
)

func (c *Client) Check(ctx context.Context, req CheckRequest) (*CheckResponse, error) {
	url := c.baseURL + "/moderation/check"

	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		observability.IncModerationRequest("error")
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		observability.IncModerationRequest("error")
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("moderation check failed: status=%d body=%s", resp.StatusCode, string(body))
	}

	var checkResp CheckResponse
	if err := json.NewDecoder(resp.Body).Decode(&checkResp); err != nil {
		observability.IncModerationRequest("error")
		return nil, fmt.Errorf("decode response: %w", err)
	}

	observability.IncModerationRequest("success")

	log.Debug().
		Str("content_id", req.ContentID).
		Str("action", string(checkResp.Action)).
		Int("labels", len(checkResp.Labels)).
		Msg("Moderation check complete")

	return &checkResp, nil
}

func (c *Client) CheckBatch(ctx context.Context, requests []CheckRequest) ([]CheckResponse, error) {
	results := make([]CheckResponse, len(requests))

	for i, req := range requests {
		resp, err := c.Check(ctx, req)
		if err != nil {
			log.Warn().
				Err(err).
				Str("content_id", req.ContentID).
				Msg("Moderation check failed, using default ALLOW")

			results[i] = CheckResponse{
				Action:    ActionAllow,
				Labels:    []Label{LabelSafe},
				CheckedAt: time.Now().UTC(),
			}
			continue
		}

		results[i] = *resp
	}

	return results, nil
}
