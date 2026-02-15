package clients

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/observability"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
)

const (
	SubjectFeedFilter          = "agents.feed.filter"
	SubjectFeedTags            = "agents.feed.tags"
	SubjectFeedSummary         = "agents.feed.summary"
	SubjectFeedTitle           = "agents.feed.title"
	SubjectFeedDescription     = "agents.feed.description"
	SubjectChatMessage         = "agents.chat.message"
	SubjectUnseenSummary       = "agents.feed.unseen_summary"
	SubjectViewGenerator       = "agents.feed.view_generator"
	SubjectPostTitle           = "agents.post.title"
	SubjectViewPromptTransformer = "agents.feed.view_prompt_transformer"
	SubjectBulletSummary       = "agents.feed.bullet_summary"
	SubjectBuildFilterPrompt   = "agents.util.build_filter_prompt"
)

// AgentsClient calls AI agents via NATS RPC
type AgentsClient struct {
	requester      *nats.Requester
	timeout        time.Duration
	maxRetries     int
	retryBaseDelay time.Duration
	cache          *redis.Client
	viewCacheTTL   time.Duration
}

func NewAgentsClient(cfg *config.Config, natsClient *nats.Client, redisClient *redis.Client, viewCacheTTL time.Duration) *AgentsClient {
	return &AgentsClient{
		requester:      nats.NewRequester(natsClient),
		timeout:        cfg.AgentsClientTimeout,
		maxRetries:     cfg.AgentsClientMaxRetries,
		retryBaseDelay: cfg.AgentsClientRetryBaseDelay,
		cache:          redisClient,
		viewCacheTTL:   viewCacheTTL,
	}
}

// FeedFilterRequest for evaluating a post against a filter
type FeedFilterRequest struct {
	FilterPrompt string  `json:"filter_prompt"`
	PostContent  string  `json:"post_content"`
	UserID       *string `json:"user_id,omitempty"`
}

// FeedFilterResponse from filter evaluation
type FeedFilterResponse struct {
	Result      bool   `json:"result"`
	Title       string `json:"title"`
	Explanation string `json:"explanation"`
}

// EvaluatePost calls the feed filter agent
func (c *AgentsClient) EvaluatePost(ctx context.Context, filterPrompt, postContent string, userID *string, requestID string) (*FeedFilterResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("feed_filter")
		observability.ObserveAgentRequestDuration("feed_filter", time.Since(start).Seconds())
	}()

	req := FeedFilterRequest{
		FilterPrompt: filterPrompt,
		PostContent:  postContent,
		UserID:       userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectFeedFilter, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("evaluate post: %w", err)
	}

	var result FeedFilterResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal filter response: %w", err)
	}

	return &result, nil
}

// FeedTagsRequest for generating tags
type FeedTagsRequest struct {
	RawPostsContent []string `json:"raw_posts_content"`
	PromptText      *string  `json:"prompt_text,omitempty"`
	FeedType        string   `json:"feed_type"`
	AvailableTags   []string `json:"available_tags"`
	UserID          *string  `json:"user_id,omitempty"`
}

// FeedTagsResponse from tag generation
type FeedTagsResponse struct {
	Tags []string `json:"tags"`
}

// GenerateTags calls the feed tags agent
func (c *AgentsClient) GenerateTags(ctx context.Context, rawPostsContent []string, feedType string, availableTags []string, promptText *string, userID *string, requestID string) (*FeedTagsResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("feed_tags")
		observability.ObserveAgentRequestDuration("feed_tags", time.Since(start).Seconds())
	}()

	req := FeedTagsRequest{
		RawPostsContent: rawPostsContent,
		PromptText:      promptText,
		FeedType:        feedType,
		AvailableTags:   availableTags,
		UserID:          userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectFeedTags, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("generate tags: %w", err)
	}

	var result FeedTagsResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal tags response: %w", err)
	}

	return &result, nil
}

// FeedSummaryRequest for summarizing posts
type FeedSummaryRequest struct {
	UserPrompt   string   `json:"user_prompt"`
	PostsContent []string `json:"posts_content"`
	Title        string   `json:"title"`
	UserID       *string  `json:"user_id,omitempty"`
}

// FeedSummaryResponse from summarization
type FeedSummaryResponse struct {
	Title   string `json:"title"`
	Summary string `json:"summary"`
}

// SummarizePosts calls the feed summary agent
func (c *AgentsClient) SummarizePosts(ctx context.Context, userPrompt string, postsContent []string, title string, userID *string, requestID string) (*FeedSummaryResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("feed_summary")
		observability.ObserveAgentRequestDuration("feed_summary", time.Since(start).Seconds())
	}()

	req := FeedSummaryRequest{
		UserPrompt:   userPrompt,
		PostsContent: postsContent,
		Title:        title,
		UserID:       userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	// Longer timeout for summarization
	timeout := 90 * time.Second
	resp, err := c.requester.RequestWithRetry(ctx, SubjectFeedSummary, req, timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("summarize posts: %w", err)
	}

	var result FeedSummaryResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal summary response: %w", err)
	}

	return &result, nil
}

// ViewGeneratorRequest for generating views
type ViewGeneratorRequest struct {
	Content    string  `json:"content"`
	ViewPrompt string  `json:"view_prompt"`
	UserID     *string `json:"user_id,omitempty"`
}

// ViewGeneratorResponse from view generation
type ViewGeneratorResponse struct {
	Content string `json:"content"`
}

func titleCacheKey(content string) string {
	h := sha256.Sum256([]byte(content))
	return "post_title:" + hex.EncodeToString(h[:16])
}

func viewCacheKey(content, viewPrompt string) string {
	h := sha256.Sum256([]byte(content + "\x00" + viewPrompt))
	return "view_gen:" + hex.EncodeToString(h[:16])
}

// GenerateView calls the view generator agent
func (c *AgentsClient) GenerateView(ctx context.Context, content, viewPrompt string, userID *string, requestID string) (*ViewGeneratorResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("view_generator")
		observability.ObserveAgentRequestDuration("view_generator", time.Since(start).Seconds())
	}()

	cacheKey := viewCacheKey(content, viewPrompt)

	if c.cache != nil {
		cached, err := c.cache.Get(ctx, cacheKey).Result()
		if err == nil {
			observability.IncCacheHit("view_generator")
			log.Debug().Str("key", cacheKey).Msg("View generator cache hit")
			return &ViewGeneratorResponse{Content: cached}, nil
		} else if err != redis.Nil {
			log.Warn().Err(err).Str("key", cacheKey).Msg("Redis cache read error")
		}
		observability.IncCacheMiss("view_generator")
	}

	req := ViewGeneratorRequest{
		Content:    content,
		ViewPrompt: viewPrompt,
		UserID:     userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectViewGenerator, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("generate view: %w", err)
	}

	var result ViewGeneratorResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal view response: %w", err)
	}

	if c.cache != nil && result.Content != "" {
		if err := c.cache.Set(ctx, cacheKey, result.Content, c.viewCacheTTL).Err(); err != nil {
			log.Warn().Err(err).Str("key", cacheKey).Msg("Redis cache write error")
		}
	}

	return &result, nil
}

// PostTitleRequest for generating post title
type PostTitleRequest struct {
	PostContent string  `json:"post_content"`
	UserID      *string `json:"user_id,omitempty"`
}

// PostTitleResponse from title generation
type PostTitleResponse struct {
	Title string `json:"title"`
}

// GeneratePostTitle calls the post title agent
func (c *AgentsClient) GeneratePostTitle(ctx context.Context, postContent string, userID *string, requestID string) (*PostTitleResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("post_title")
		observability.ObserveAgentRequestDuration("post_title", time.Since(start).Seconds())
	}()

	if c.cache != nil {
		key := titleCacheKey(postContent)
		if cached, err := c.cache.Get(ctx, key).Result(); err == nil {
			log.Debug().Str("key", key).Msg("Post title cache hit")
			observability.IncCacheHit("post_title")
			return &PostTitleResponse{Title: cached}, nil
		}
		observability.IncCacheMiss("post_title")
	}

	req := PostTitleRequest{
		PostContent: postContent,
		UserID:      userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	timeout := 45 * time.Second
	resp, err := c.requester.RequestWithRetry(ctx, SubjectPostTitle, req, timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("generate post title: %w", err)
	}

	var result PostTitleResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal title response: %w", err)
	}

	if c.cache != nil && result.Title != "" {
		key := titleCacheKey(postContent)
		if err := c.cache.SetEx(ctx, key, result.Title, c.viewCacheTTL).Err(); err != nil {
			log.Warn().Err(err).Msg("Failed to cache post title")
		}
	}

	return &result, nil
}

// FeedDescriptionRequest for generating feed description
type FeedDescriptionRequest struct {
	Prompt   *string  `json:"prompt,omitempty"`
	Sources  []string `json:"sources,omitempty"`
	FeedType *string  `json:"feed_type,omitempty"`
	UserID   *string  `json:"user_id,omitempty"`
}

// FeedDescriptionResponse from description generation
type FeedDescriptionResponse struct {
	Description string `json:"description"`
}

// GenerateFeedDescription calls the feed description agent
func (c *AgentsClient) GenerateFeedDescription(ctx context.Context, prompt *string, sources []string, feedType *string, userID *string, requestID string) (*FeedDescriptionResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("feed_description")
		observability.ObserveAgentRequestDuration("feed_description", time.Since(start).Seconds())
	}()

	req := FeedDescriptionRequest{
		Prompt:   prompt,
		Sources:  sources,
		FeedType: feedType,
		UserID:   userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectFeedDescription, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("generate feed description: %w", err)
	}

	var result FeedDescriptionResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal description response: %w", err)
	}

	return &result, nil
}

// LocalizedName for view/filter names
type LocalizedName struct {
	Ru string `json:"ru"`
	En string `json:"en"`
}

// ViewConfig for view configuration
type ViewConfig struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

// FilterConfig for filter configuration
type FilterConfig struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

// ViewPromptTransformerRequest for transforming views/filters
type ViewPromptTransformerRequest struct {
	Views        []string `json:"views"`
	Filters      []string `json:"filters"`
	ContextPosts []string `json:"context_posts,omitempty"`
	UserID       *string  `json:"user_id,omitempty"`
}

// ViewPromptTransformerResponse from transformation
type ViewPromptTransformerResponse struct {
	Views   []ViewConfig   `json:"views"`
	Filters []FilterConfig `json:"filters"`
}

// TransformViewsAndFilters calls the view prompt transformer agent
func (c *AgentsClient) TransformViewsAndFilters(ctx context.Context, views, filters, contextPosts []string, userID *string, requestID string) (*ViewPromptTransformerResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("view_prompt_transformer")
		observability.ObserveAgentRequestDuration("view_prompt_transformer", time.Since(start).Seconds())
	}()

	req := ViewPromptTransformerRequest{
		Views:        views,
		Filters:      filters,
		ContextPosts: contextPosts,
		UserID:       userID,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectViewPromptTransformer, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("transform views and filters: %w", err)
	}

	var result ViewPromptTransformerResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal transformer response: %w", err)
	}

	return &result, nil
}

// BuildFilterPromptRequest for building filter prompts
type BuildFilterPromptRequest struct {
	UserInstruction *string  `json:"user_instruction,omitempty"`
	Filters         []string `json:"filters,omitempty"`
}

// BuildFilterPromptResponse from prompt building
type BuildFilterPromptResponse struct {
	Prompt string `json:"prompt"`
}

// BuildFilterPrompt calls the build filter prompt agent
func (c *AgentsClient) BuildFilterPrompt(ctx context.Context, userInstruction *string, filters []string, requestID string) (*BuildFilterPromptResponse, error) {
	start := time.Now()
	defer func() {
		observability.IncAgentRequests("build_filter_prompt")
		observability.ObserveAgentRequestDuration("build_filter_prompt", time.Since(start).Seconds())
	}()

	req := BuildFilterPromptRequest{
		UserInstruction: userInstruction,
		Filters:         filters,
	}

	headers := map[string]string{}
	if requestID != "" {
		headers["X-Request-ID"] = requestID
	}

	resp, err := c.requester.RequestWithRetry(ctx, SubjectBuildFilterPrompt, req, c.timeout, headers, c.maxRetries, c.retryBaseDelay)
	if err != nil {
		return nil, fmt.Errorf("build filter prompt: %w", err)
	}

	var result BuildFilterPromptResponse
	if err := json.Unmarshal(resp, &result); err != nil {
		return nil, fmt.Errorf("unmarshal filter prompt response: %w", err)
	}

	log.Debug().
		Str("prompt", result.Prompt).
		Msg("Built filter prompt")

	return &result, nil
}
