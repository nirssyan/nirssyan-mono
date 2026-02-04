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

type TransformViewsRequest struct {
	RawViews string `json:"raw_views"`
}

type ViewConfig struct {
	Title      string `json:"title"`
	Style      string `json:"style"`
	Conditions string `json:"conditions"`
}

type TransformViewsResponse struct {
	Views []ViewConfig `json:"views"`
}

func (c *AgentsClient) TransformViewsToConfig(ctx context.Context, rawViews string) ([]ViewConfig, error) {
	req := TransformViewsRequest{RawViews: rawViews}

	var resp TransformViewsResponse
	// NOTE: This subject does not exist in Python agents yet
	if err := c.request(ctx, "agents.feed.view_prompt_transformer", req, &resp); err != nil {
		return nil, fmt.Errorf("transform views: %w", err)
	}

	return resp.Views, nil
}

type TransformFiltersRequest struct {
	RawFilters string `json:"raw_filters"`
}

type FilterConfig struct {
	Type       string `json:"type"`
	Conditions string `json:"conditions"`
}

type TransformFiltersResponse struct {
	Filters []FilterConfig `json:"filters"`
}

func (c *AgentsClient) TransformFiltersToConfig(ctx context.Context, rawFilters string) ([]FilterConfig, error) {
	req := TransformFiltersRequest{RawFilters: rawFilters}

	var resp TransformFiltersResponse
	// NOTE: Uses build_filter_prompt agent which returns prompt string, not filter config
	if err := c.request(ctx, "agents.util.build_filter_prompt", req, &resp); err != nil {
		return nil, fmt.Errorf("transform filters: %w", err)
	}

	return resp.Filters, nil
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
