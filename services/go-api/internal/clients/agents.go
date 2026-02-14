package clients

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
	"github.com/shopspring/decimal"
)

const DefaultTimeout = 120 * time.Second

type AgentsClient struct {
	nc      *nats.Conn
	timeout time.Duration
}

func NewAgentsClient(nc *nats.Conn) *AgentsClient {
	return &AgentsClient{
		nc:      nc,
		timeout: DefaultTimeout,
	}
}

type GenerateTitleRequest struct {
	FeedFilters map[string]interface{} `json:"feed_filters"`
	SamplePosts []string               `json:"sample_posts"`
	UserID      *string                `json:"user_id,omitempty"`
}

type SourceInfo struct {
	URL         string `json:"url"`
	Title       string `json:"title"`
	Description string `json:"description"`
}

type GenerateTitleResponse struct {
	Title string `json:"title"`
}

func (c *AgentsClient) GenerateFeedTitle(ctx context.Context, sources []SourceInfo, samplePosts []string) (string, error) {
	// Try NATS first with timeout
	if c.nc != nil {
		timeoutCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
		defer cancel()

		// Python agent expects sources as array of URL strings, not SourceInfo objects
		sourceURLs := make([]string, len(sources))
		for i, s := range sources {
			sourceURLs[i] = s.URL
		}

		if samplePosts == nil {
			samplePosts = []string{}
		}

		req := GenerateTitleRequest{
			FeedFilters: map[string]interface{}{
				"sources": sourceURLs,
			},
			SamplePosts: samplePosts,
		}

		var resp GenerateTitleResponse
		err := c.request(timeoutCtx, "agents.feed.title", req, &resp)
		if err != nil {
			log.Warn().Err(err).Msg("NATS title generation failed, using fallback")
		} else if resp.Title != "" {
			return resp.Title, nil
		}
	}

	// Fallback: generate simple title from sources
	return c.generateSimpleTitle(sources), nil
}

func (c *AgentsClient) generateSimpleTitle(sources []SourceInfo) string {
	if len(sources) == 0 {
		return "My Feed"
	}

	// Extract readable name from first source
	source := sources[0]

	// Use title if available
	if source.Title != "" {
		return source.Title
	}

	// Extract channel name from Telegram URL
	url := source.URL
	if strings.Contains(url, "t.me/") {
		parts := strings.Split(url, "t.me/")
		if len(parts) > 1 {
			channel := strings.Split(parts[1], "/")[0]
			channel = strings.TrimPrefix(channel, "@")
			if channel != "" {
				return "@" + channel
			}
		}
	}

	// For @username format
	if strings.HasPrefix(url, "@") {
		return url
	}

	// Generic fallback
	return "My Feed"
}

type LocalizedName struct {
	En string `json:"en"`
	Ru string `json:"ru"`
}

type ResolvedViewConfig struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

type ResolvedFilterConfig struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

type ViewPromptTransformerRequest struct {
	Views   []string `json:"views"`
	Filters []string `json:"filters"`
}

type ViewPromptTransformerResponse struct {
	Views   []ResolvedViewConfig   `json:"views"`
	Filters []ResolvedFilterConfig `json:"filters"`
}

func (c *AgentsClient) TransformViewsAndFilters(ctx context.Context, views, filters []string) (*ViewPromptTransformerResponse, error) {
	req := ViewPromptTransformerRequest{Views: views, Filters: filters}
	var resp ViewPromptTransformerResponse
	if err := c.request(ctx, "agents.feed.view_prompt_transformer", req, &resp); err != nil {
		return nil, fmt.Errorf("transform views and filters: %w", err)
	}
	return &resp, nil
}

type SummarizeUnseenRequest struct {
	FeedID     string         `json:"feed_id"`
	PostsData  []PostSummary  `json:"posts_data"`
	FeedConfig FeedConfigInfo `json:"feed_config"`
}

type PostSummary struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	SourceURL string `json:"source_url"`
}

type FeedConfigInfo struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

type SummarizeUnseenResponse struct {
	Summary string `json:"summary"`
}

func (c *AgentsClient) SummarizeUnseen(ctx context.Context, feedID string, posts []PostSummary, feedConfig FeedConfigInfo) (string, error) {
	req := SummarizeUnseenRequest{
		FeedID:     feedID,
		PostsData:  posts,
		FeedConfig: feedConfig,
	}

	var resp SummarizeUnseenResponse
	if err := c.request(ctx, "agents.feed.unseen_summary", req, &resp); err != nil {
		return "", fmt.Errorf("summarize unseen: %w", err)
	}

	return resp.Summary, nil
}

type EvaluatePostRequest struct {
	RawPostID    string                 `json:"raw_post_id"`
	Content      string                 `json:"content"`
	Title        string                 `json:"title"`
	SourceURL    string                 `json:"source_url"`
	FilterConfig map[string]interface{} `json:"filter_config"`
}

type EvaluatePostResponse struct {
	Passed   bool    `json:"passed"`
	Reason   string  `json:"reason"`
	Score    float64 `json:"score"`
	Category string  `json:"category"`
}

func (c *AgentsClient) EvaluatePost(ctx context.Context, req EvaluatePostRequest) (*EvaluatePostResponse, error) {
	var resp EvaluatePostResponse
	if err := c.request(ctx, "agents.feed.filter", req, &resp); err != nil {
		return nil, fmt.Errorf("evaluate post: %w", err)
	}
	return &resp, nil
}

type GenerateViewRequest struct {
	RawPostID  string                 `json:"raw_post_id"`
	Content    string                 `json:"content"`
	Title      string                 `json:"title"`
	SourceURL  string                 `json:"source_url"`
	ViewConfig map[string]interface{} `json:"view_config"`
}

type GenerateViewResponse struct {
	Title       string           `json:"title"`
	Description string           `json:"description"`
	ImageURL    string           `json:"image_url"`
	LLMCost     *decimal.Decimal `json:"llm_cost,omitempty"`
}

func (c *AgentsClient) GenerateView(ctx context.Context, req GenerateViewRequest) (*GenerateViewResponse, error) {
	var resp GenerateViewResponse
	if err := c.request(ctx, "agents.feed.view_generator", req, &resp); err != nil {
		return nil, fmt.Errorf("generate view: %w", err)
	}
	return &resp, nil
}

func (c *AgentsClient) request(ctx context.Context, subject string, req interface{}, resp interface{}) error {
	data, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("marshal request: %w", err)
	}

	log.Debug().
		Str("subject", subject).
		RawJSON("request", data).
		Msg("NATS request")

	msg, err := c.nc.RequestWithContext(ctx, subject, data)
	if err != nil {
		return fmt.Errorf("nats request: %w", err)
	}

	if err := json.Unmarshal(msg.Data, resp); err != nil {
		return fmt.Errorf("unmarshal response: %w", err)
	}

	return nil
}
