package services

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/sync/errgroup"

	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-processor/repository"
	"github.com/rs/zerolog/log"
)

type FeedProcessingService struct {
	cfg                *config.Config
	agentsClient       *clients.AgentsClient
	promptRepo         *repository.PromptRepository
	rawPostRepo        *repository.RawPostRepository
	postRepo           *repository.PostRepository
	feedRepo           *repository.FeedRepository
	offsetRepo         *repository.OffsetRepository
	publisher          *nats.Publisher
	mediaWarmerClient  *clients.MediaWarmerClient
}

func NewFeedProcessingService(
	cfg *config.Config,
	agentsClient *clients.AgentsClient,
	promptRepo *repository.PromptRepository,
	rawPostRepo *repository.RawPostRepository,
	postRepo *repository.PostRepository,
	feedRepo *repository.FeedRepository,
	offsetRepo *repository.OffsetRepository,
	publisher *nats.Publisher,
	mediaWarmerClient *clients.MediaWarmerClient,
) *FeedProcessingService {
	return &FeedProcessingService{
		cfg:               cfg,
		agentsClient:      agentsClient,
		promptRepo:        promptRepo,
		rawPostRepo:       rawPostRepo,
		postRepo:          postRepo,
		feedRepo:          feedRepo,
		offsetRepo:        offsetRepo,
		publisher:         publisher,
		mediaWarmerClient: mediaWarmerClient,
	}
}

// ProcessRawPostEvent handles raw post created events
func (s *FeedProcessingService) ProcessRawPostEvent(ctx context.Context, event domain.RawPostCreatedEvent) error {
	logger := log.With().
		Str("event_type", event.EventType).
		Str("event_id", event.EventID.String()).
		Str("raw_feed_id", event.RawFeedID.String()).
		Int("post_count", len(event.RawPostIDs)).
		Logger()

	logger.Info().Msg("Processing raw post event")

	// Get prompts linked to this raw feed
	prompts, err := s.promptRepo.GetPromptsByRawFeedID(ctx, event.RawFeedID)
	if err != nil {
		return fmt.Errorf("get prompts by raw feed: %w", err)
	}

	if len(prompts) == 0 {
		logger.Debug().Msg("No prompts linked to raw feed, skipping")
		return nil
	}

	// Get raw posts
	rawPosts, err := s.rawPostRepo.GetByIDs(ctx, event.RawPostIDs)
	if err != nil {
		return fmt.Errorf("get raw posts: %w", err)
	}

	if len(rawPosts) == 0 {
		logger.Warn().Msg("No raw posts found")
		return nil
	}

	// Warm media for all raw posts (fire-and-forget via NATS RPC)
	if s.mediaWarmerClient != nil {
		for _, rp := range rawPosts {
			s.mediaWarmerClient.WarmMedia(ctx, rp.MediaObjects)
		}
	}

	// Process each prompt
	for _, prompt := range prompts {
		if err := s.processPromptForRawPosts(ctx, prompt, rawPosts, event.RawFeedID); err != nil {
			logger.Error().
				Err(err).
				Str("prompt_id", prompt.ID.String()).
				Msg("Failed to process prompt")
			continue
		}
	}

	return nil
}

// processPromptForRawPosts processes raw posts for a single prompt
func (s *FeedProcessingService) processPromptForRawPosts(ctx context.Context, prompt domain.Prompt, rawPosts []domain.RawPost, rawFeedID uuid.UUID) error {
	logger := log.With().
		Str("prompt_id", prompt.ID.String()).
		Str("feed_id", prompt.FeedID.String()).
		Str("feed_type", prompt.FeedType).
		Logger()

	logger.Info().Int("raw_posts", len(rawPosts)).Msg("Processing prompt")

	switch prompt.FeedType {
	case "SINGLE_POST":
		return s.processSinglePostPrompt(ctx, prompt, rawPosts, rawFeedID)
	case "DIGEST":
		logger.Debug().Msg("Digest processing deferred to scheduled event")
		return nil
	default:
		logger.Warn().Msg("Unknown feed type")
		return nil
	}
}

type postResult struct {
	post       *domain.Post
	rawPost    domain.RawPost
	inserted   bool
	sourceURLs []string
}

// processSinglePostPrompt processes posts for SINGLE_POST feed type
func (s *FeedProcessingService) processSinglePostPrompt(ctx context.Context, prompt domain.Prompt, rawPosts []domain.RawPost, rawFeedID uuid.UUID) error {
	logger := log.With().
		Str("prompt_id", prompt.ID.String()).
		Str("feed_id", prompt.FeedID.String()).
		Logger()

	filterPrompt, err := s.extractFilterPrompt(prompt.FiltersConfig)
	if err != nil {
		return fmt.Errorf("extract filter prompt: %w", err)
	}

	views, err := s.parseViewsConfig(prompt.ViewsConfig)
	if err != nil {
		return fmt.Errorf("parse views config: %w", err)
	}

	var userID uuid.UUID
	if s.publisher != nil {
		userID, err = s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
		if err != nil {
			logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
		}
		if userID == uuid.Nil {
			logger.Warn().Str("feed_id", prompt.FeedID.String()).Msg("Feed owner not found, skipping post.created notifications")
		}
	}

	var (
		mu      sync.Mutex
		results []postResult
	)

	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(s.cfg.LLMConcurrentRequests)

	for _, rawPost := range rawPosts {
		rp := rawPost
		g.Go(func() error {
			if rp.ModerationAction != nil && *rp.ModerationAction == "block" {
				logger.Debug().Str("raw_post_id", rp.ID.String()).Msg("Skipping blocked post")
				mu.Lock()
				results = append(results, postResult{rawPost: rp})
				mu.Unlock()
				return nil
			}

			if filterPrompt != "" {
				filterResp, err := s.agentsClient.EvaluatePost(gctx, filterPrompt, rp.Content, nil, "")
				if err != nil {
					logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to evaluate post")
					return nil
				}
				if !filterResp.Result {
					logger.Debug().Str("raw_post_id", rp.ID.String()).Str("explanation", filterResp.Explanation).Msg("Post filtered out")
					mu.Lock()
					results = append(results, postResult{rawPost: rp})
					mu.Unlock()
					return nil
				}
			}

			post, err := s.processPostAICalls(gctx, rp, views, prompt.FeedID)
			if err != nil {
				logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to process post AI calls")
				return nil
			}

			var sourceURLs []string
			if rp.SourceURL != nil && *rp.SourceURL != "" {
				sourceURLs = append(sourceURLs, *rp.SourceURL)
			}

			inserted, err := s.postRepo.CreatePostWithSources(gctx, post, sourceURLs)
			if err != nil {
				logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to create post")
				return nil
			}

			mu.Lock()
			results = append(results, postResult{post: post, rawPost: rp, inserted: inserted, sourceURLs: sourceURLs})
			mu.Unlock()
			return nil
		})
	}

	_ = g.Wait()

	var lastProcessedCreatedAt time.Time
	var lastProcessedID uuid.UUID
	createdCount := 0

	for _, r := range results {
		if r.rawPost.CreatedAt.After(lastProcessedCreatedAt) {
			lastProcessedCreatedAt = r.rawPost.CreatedAt
			lastProcessedID = r.rawPost.ID
		}
		if r.post == nil || !r.inserted {
			continue
		}
		observability.IncPostsCreated("SINGLE_POST")
		createdCount++

		if s.publisher != nil && userID != uuid.Nil {
			if err := s.publisher.PublishPostCreated(r.post.ID, prompt.FeedID, userID); err != nil {
				logger.Warn().Err(err).Str("post_id", r.post.ID.String()).Msg("Failed to publish post.created event")
			}
		} else if s.publisher == nil {
			logger.Warn().Msg("Publisher is nil, skipping post.created notification")
		}
	}

	if lastProcessedID != uuid.Nil {
		if err := s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, lastProcessedID, lastProcessedCreatedAt); err != nil {
			logger.Error().Err(err).Msg("Failed to update offset")
		}
	}

	logger.Info().
		Int("created", createdCount).
		Int("total", len(rawPosts)).
		Msg("Finished processing single post prompt")

	return nil
}

// ProcessDigestEvent handles digest scheduled events
func (s *FeedProcessingService) ProcessDigestEvent(ctx context.Context, event domain.DigestScheduledEvent) error {
	logger := log.With().
		Str("prompt_id", event.PromptID.String()).
		Logger()

	logger.Info().Msg("Processing digest event")

	// Get prompt
	prompt, err := s.promptRepo.GetPromptByID(ctx, event.PromptID)
	if err != nil {
		return fmt.Errorf("get prompt: %w", err)
	}
	if prompt == nil {
		return fmt.Errorf("prompt not found: %s", event.PromptID)
	}

	// Get raw feed IDs
	rawFeedIDs, err := s.offsetRepo.GetRawFeedIDsByPromptID(ctx, prompt.ID)
	if err != nil {
		return fmt.Errorf("get raw feed ids: %w", err)
	}

	// Collect all unprocessed posts
	var allPosts []domain.RawPost
	for _, rawFeedID := range rawFeedIDs {
		posts, err := s.rawPostRepo.GetUnprocessedByPromptAndRawFeed(ctx, prompt.ID, rawFeedID, 100)
		if err != nil {
			logger.Error().Err(err).Str("raw_feed_id", rawFeedID.String()).Msg("Failed to get posts")
			continue
		}
		allPosts = append(allPosts, posts...)
	}

	if len(allPosts) == 0 {
		logger.Info().Msg("No posts for digest")
		return nil
	}

	return s.processDigest(ctx, *prompt, allPosts, rawFeedIDs)
}

// processDigest creates a digest post from a collection of raw posts
func (s *FeedProcessingService) processDigest(ctx context.Context, prompt domain.Prompt, allPosts []domain.RawPost, rawFeedIDs []uuid.UUID) error {
	logger := log.With().
		Str("prompt_id", prompt.ID.String()).
		Str("feed_id", prompt.FeedID.String()).
		Logger()

	var contents []string
	for _, p := range allPosts {
		contents = append(contents, p.Content)
	}

	filterPrompt, _ := s.extractFilterPrompt(prompt.FiltersConfig)
	if filterPrompt == "" {
		filterPrompt = "Summarize the following posts"
	}

	summaryResp, err := s.agentsClient.SummarizePosts(ctx, filterPrompt, contents, "Digest", nil, "")
	if err != nil {
		return fmt.Errorf("summarize posts: %w", err)
	}

	views, _ := s.parseViewsConfig(prompt.ViewsConfig)
	postViews, _ := json.Marshal(map[string]string{
		"default": summaryResp.Summary,
	})

	if len(views) > 0 {
		var (
			mu       sync.Mutex
			viewsMap map[string]string
		)
		json.Unmarshal(postViews, &viewsMap)

		g, gctx := errgroup.WithContext(ctx)
		for _, view := range views {
			v := view
			g.Go(func() error {
				viewResp, err := s.agentsClient.GenerateView(gctx, summaryResp.Summary, v.Prompt, nil, "")
				if err != nil {
					logger.Warn().Err(err).Str("view", v.Name.En).Msg("Failed to generate view")
					return nil
				}
				mu.Lock()
				viewsMap[v.Name.En] = viewResp.Content
				mu.Unlock()
				return nil
			})
		}
		g.Wait()
		postViews, _ = json.Marshal(viewsMap)
	}

	post := &domain.Post{
		ID:                        uuid.New(),
		CreatedAt:                 time.Now(),
		FeedID:                    prompt.FeedID,
		Title:                     &summaryResp.Title,
		MediaObjects:              json.RawMessage("[]"),
		Views:                     postViews,
		ModerationLabels:          []string{},
		ModerationMatchedEntities: json.RawMessage("[]"),
	}

	if err := s.postRepo.CreatePost(ctx, post); err != nil {
		return fmt.Errorf("create digest post: %w", err)
	}

	observability.IncPostsCreated("DIGEST")

	if s.publisher != nil {
		userID, err := s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
		if err != nil {
			logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
		} else if userID != uuid.Nil {
			if err := s.publisher.PublishPostCreated(post.ID, prompt.FeedID, userID); err != nil {
				logger.Warn().Err(err).Str("post_id", post.ID.String()).Msg("Failed to publish post.created event")
			}
		} else {
			logger.Warn().Str("feed_id", prompt.FeedID.String()).Msg("Feed owner not found, skipping digest post.created notification")
		}
	} else {
		logger.Warn().Msg("Publisher is nil, skipping digest post.created notification")
	}

	for _, rawFeedID := range rawFeedIDs {
		posts, _ := s.rawPostRepo.GetUnprocessedByPromptAndRawFeed(ctx, prompt.ID, rawFeedID, 1)
		if len(posts) > 0 {
			last := posts[len(posts)-1]
			s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, last.ID, last.CreatedAt)
		}
	}

	s.promptRepo.UpdateLastExecution(ctx, prompt.ID)

	logger.Info().
		Int("posts_processed", len(allPosts)).
		Str("title", summaryResp.Title).
		Msg("Digest created")

	return nil
}

// ProcessFeedCreatedEvent handles feed created events for background processing
func (s *FeedProcessingService) ProcessFeedCreatedEvent(ctx context.Context, event domain.FeedCreatedEvent) error {
	logger := log.With().
		Str("feed_id", event.FeedID.String()).
		Str("prompt_id", event.PromptID.String()).
		Logger()

	logger.Info().Msg("Processing feed created event")

	// Get prompt
	prompt, err := s.promptRepo.GetPromptByID(ctx, event.PromptID)
	if err != nil {
		return fmt.Errorf("get prompt: %w", err)
	}
	if prompt == nil {
		return fmt.Errorf("prompt not found: %s", event.PromptID)
	}

	// Generate description if needed
	if event.PromptText != "" {
		descResp, err := s.agentsClient.GenerateFeedDescription(ctx, &event.PromptText, event.Sources, &event.FeedType, nil, "")
		if err != nil {
			logger.Warn().Err(err).Msg("Failed to generate description")
		} else {
			if err := s.feedRepo.UpdateDescription(ctx, event.FeedID, descResp.Description); err != nil {
				logger.Warn().Err(err).Msg("Failed to update description")
			}
		}
	}

	// Transform views and filters before initial sync
	if len(event.ViewsRaw) > 0 || len(event.FiltersRaw) > 0 {
		viewsRaw := make([]string, 0)
		filtersRaw := make([]string, 0)
		for _, v := range event.ViewsRaw {
			if text, ok := v["text"].(string); ok {
				viewsRaw = append(viewsRaw, text)
			}
		}
		for _, f := range event.FiltersRaw {
			if text, ok := f["text"].(string); ok {
				filtersRaw = append(filtersRaw, text)
			}
		}

		if len(viewsRaw) > 0 || len(filtersRaw) > 0 {
			transformResp, err := s.agentsClient.TransformViewsAndFilters(ctx, viewsRaw, filtersRaw, nil, nil, "")
			if err != nil {
				logger.Warn().Err(err).Msg("Failed to transform views/filters")
			} else {
				if len(transformResp.Views) > 0 {
					viewsConfig, _ := json.Marshal(transformResp.Views)
					s.promptRepo.UpdateViewsConfig(ctx, event.PromptID, viewsConfig)
				}
				if len(transformResp.Filters) > 0 {
					filtersConfig, _ := json.Marshal(transformResp.Filters)
					s.promptRepo.UpdateFiltersConfig(ctx, event.PromptID, filtersConfig)
				}
				logger.Info().Msg("Views/filters transformed successfully")
			}
		}
	}

	// Mark feed as finished
	if err := s.feedRepo.MarkCreatingFinished(ctx, event.FeedID); err != nil {
		return fmt.Errorf("mark finished: %w", err)
	}

	// Publish feed.creation_finished event for WebSocket notifications
	if s.publisher != nil {
		if err := s.publisher.PublishFeedCreationFinished(event.FeedID, event.UserID); err != nil {
			logger.Warn().Err(err).Msg("Failed to publish feed.creation_finished event")
		}
	}

	// Trigger initial sync now that views are transformed
	if s.publisher != nil {
		if err := s.publisher.PublishFeedInitialSync(event.FeedID, event.PromptID, event.UserID); err != nil {
			logger.Warn().Err(err).Msg("Failed to publish feed.initial_sync")
		}
	}

	logger.Info().Msg("Feed created event processed")
	return nil
}

// ProcessFeedInitialSyncEvent handles initial sync events
func (s *FeedProcessingService) ProcessFeedInitialSyncEvent(ctx context.Context, event domain.FeedInitialSyncEvent) error {
	logger := log.With().
		Str("feed_id", event.FeedID.String()).
		Str("prompt_id", event.PromptID.String()).
		Logger()

	logger.Info().Msg("Processing initial sync event")

	// Get prompt
	prompt, err := s.promptRepo.GetPromptByID(ctx, event.PromptID)
	if err != nil {
		return fmt.Errorf("get prompt: %w", err)
	}
	if prompt == nil {
		return fmt.Errorf("prompt not found: %s", event.PromptID)
	}

	// Get raw feed IDs
	rawFeedIDs, err := s.offsetRepo.GetRawFeedIDsByPromptID(ctx, prompt.ID)
	if err != nil {
		return fmt.Errorf("get raw feed ids: %w", err)
	}

	// Process initial posts from each raw feed
	totalCreated := 0

	if prompt.FeedType == "DIGEST" {
		var allPosts []domain.RawPost
		for _, rawFeedID := range rawFeedIDs {
			rawPosts, err := s.rawPostRepo.GetLatestByRawFeed(ctx, rawFeedID, s.cfg.InitialSyncMaxRawPosts)
			if err != nil {
				logger.Error().Err(err).Str("raw_feed_id", rawFeedID.String()).Msg("Failed to get posts")
				continue
			}
			allPosts = append(allPosts, rawPosts...)
		}
		if len(allPosts) > 0 {
			if err := s.processDigest(ctx, *prompt, allPosts, rawFeedIDs); err != nil {
				logger.Error().Err(err).Msg("Failed to create initial digest")
			} else {
				totalCreated = 1
			}
		}
	} else {
		for _, rawFeedID := range rawFeedIDs {
			rawPosts, err := s.rawPostRepo.GetLatestByRawFeed(ctx, rawFeedID, s.cfg.InitialSyncMaxRawPosts)
			if err != nil {
				logger.Error().Err(err).Str("raw_feed_id", rawFeedID.String()).Msg("Failed to get posts")
				continue
			}

			if len(rawPosts) == 0 {
				continue
			}

			created, err := s.processPromptForRawPostsWithLimit(ctx, *prompt, rawPosts, rawFeedID, s.cfg.InitialSyncTargetPosts-totalCreated)
			if err != nil {
				logger.Error().Err(err).Msg("Failed to process initial posts")
			}
			totalCreated += created

			if totalCreated >= s.cfg.InitialSyncTargetPosts {
				logger.Info().Int("created", totalCreated).Msg("Reached initial sync target, stopping")
				break
			}
		}
	}

	logger.Info().Int("total_created", totalCreated).Msg("Initial sync completed")
	return nil
}

// processPromptForRawPostsWithLimit processes posts with a limit on created posts (for initial sync)
func (s *FeedProcessingService) processPromptForRawPostsWithLimit(ctx context.Context, prompt domain.Prompt, rawPosts []domain.RawPost, rawFeedID uuid.UUID, limit int) (int, error) {
	if limit <= 0 {
		return 0, nil
	}

	logger := log.With().
		Str("prompt_id", prompt.ID.String()).
		Str("feed_id", prompt.FeedID.String()).
		Int("limit", limit).
		Logger()

	logger.Info().Int("raw_posts", len(rawPosts)).Msg("Processing prompt with limit")

	if prompt.FeedType != "SINGLE_POST" {
		logger.Debug().Msg("Non-SINGLE_POST feed type, skipping limited processing")
		return 0, nil
	}

	filterPrompt, err := s.extractFilterPrompt(prompt.FiltersConfig)
	if err != nil {
		return 0, fmt.Errorf("extract filter prompt: %w", err)
	}

	views, err := s.parseViewsConfig(prompt.ViewsConfig)
	if err != nil {
		return 0, fmt.Errorf("parse views config: %w", err)
	}

	var userID uuid.UUID
	if s.publisher != nil {
		userID, err = s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
		if err != nil {
			logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
		}
		if userID == uuid.Nil {
			logger.Warn().Str("feed_id", prompt.FeedID.String()).Msg("Feed owner not found, skipping post.created notifications")
		}
	}

	var (
		mu      sync.Mutex
		results []postResult
	)

	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(s.cfg.LLMConcurrentRequests)

	for _, rawPost := range rawPosts {
		rp := rawPost
		g.Go(func() error {
			if rp.ModerationAction != nil && *rp.ModerationAction == "block" {
				logger.Debug().Str("raw_post_id", rp.ID.String()).Msg("Skipping blocked post")
				mu.Lock()
				results = append(results, postResult{rawPost: rp})
				mu.Unlock()
				return nil
			}

			if filterPrompt != "" {
				filterResp, err := s.agentsClient.EvaluatePost(gctx, filterPrompt, rp.Content, nil, "")
				if err != nil {
					logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to evaluate post")
					return nil
				}
				if !filterResp.Result {
					logger.Debug().Str("raw_post_id", rp.ID.String()).Str("explanation", filterResp.Explanation).Msg("Post filtered out")
					mu.Lock()
					results = append(results, postResult{rawPost: rp})
					mu.Unlock()
					return nil
				}
			}

			post, err := s.processPostAICalls(gctx, rp, views, prompt.FeedID)
			if err != nil {
				logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to process post AI calls")
				return nil
			}

			var sourceURLs []string
			if rp.SourceURL != nil && *rp.SourceURL != "" {
				sourceURLs = append(sourceURLs, *rp.SourceURL)
			}

			inserted, err := s.postRepo.CreatePostWithSources(gctx, post, sourceURLs)
			if err != nil {
				logger.Error().Err(err).Str("raw_post_id", rp.ID.String()).Msg("Failed to create post")
				return nil
			}

			mu.Lock()
			results = append(results, postResult{post: post, rawPost: rp, inserted: inserted, sourceURLs: sourceURLs})
			mu.Unlock()
			return nil
		})
	}

	_ = g.Wait()

	var lastProcessedCreatedAt time.Time
	var lastProcessedID uuid.UUID
	createdCount := 0

	for _, r := range results {
		if r.rawPost.CreatedAt.After(lastProcessedCreatedAt) {
			lastProcessedCreatedAt = r.rawPost.CreatedAt
			lastProcessedID = r.rawPost.ID
		}
		if r.post == nil || !r.inserted {
			continue
		}
		observability.IncPostsCreated("SINGLE_POST")
		createdCount++

		if s.publisher != nil && userID != uuid.Nil {
			if err := s.publisher.PublishPostCreated(r.post.ID, prompt.FeedID, userID); err != nil {
				logger.Warn().Err(err).Str("post_id", r.post.ID.String()).Msg("Failed to publish post.created event")
			}
		} else if s.publisher == nil {
			logger.Warn().Msg("Publisher is nil, skipping post.created notification")
		}
	}

	if lastProcessedID != uuid.Nil {
		if err := s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, lastProcessedID, lastProcessedCreatedAt); err != nil {
			logger.Error().Err(err).Msg("Failed to update offset")
		}
	}

	logger.Info().
		Int("created", createdCount).
		Int("total_raw", len(rawPosts)).
		Int("limit", limit).
		Msg("Finished processing with limit")

	return createdCount, nil
}

// Helper methods

func (s *FeedProcessingService) extractFilterPrompt(filtersConfig json.RawMessage) (string, error) {
	if len(filtersConfig) == 0 || string(filtersConfig) == "null" {
		return "", nil
	}

	var filters []struct {
		Prompt string `json:"prompt"`
	}
	if err := json.Unmarshal(filtersConfig, &filters); err != nil {
		// filters_config might be in an unsupported format (e.g., raw strings from go-api)
		// Log warning and return empty to skip filtering
		log.Warn().
			Err(err).
			RawJSON("filters_config", filtersConfig).
			Msg("Failed to parse filters_config, skipping filter")
		return "", nil
	}

	if len(filters) > 0 {
		return filters[0].Prompt, nil
	}

	return "", nil
}

func (s *FeedProcessingService) parseViewsConfig(viewsConfig json.RawMessage) ([]domain.View, error) {
	if len(viewsConfig) == 0 || string(viewsConfig) == "null" {
		return nil, nil
	}

	var views []domain.View
	if err := json.Unmarshal(viewsConfig, &views); err != nil {
		var rawStrings []string
		if err2 := json.Unmarshal(viewsConfig, &rawStrings); err2 == nil && len(rawStrings) > 0 {
			log.Warn().
				Strs("raw_views", rawStrings).
				Msg("views_config contains raw strings (not yet transformed), skipping custom views")
		} else {
			log.Warn().
				Err(err).
				RawJSON("views_config", viewsConfig).
				Msg("Failed to parse views_config, using default view")
		}
		return nil, nil
	}

	return views, nil
}

func (s *FeedProcessingService) generatePostViewsParallel(ctx context.Context, rawPost domain.RawPost, views []domain.View) (json.RawMessage, error) {
	var (
		mu     sync.Mutex
		result = map[string]string{"default": rawPost.Content}
	)

	g, gctx := errgroup.WithContext(ctx)
	for _, view := range views {
		v := view
		g.Go(func() error {
			viewResp, err := s.agentsClient.GenerateView(gctx, rawPost.Content, v.Prompt, nil, "")
			if err != nil {
				log.Warn().Err(err).Str("view", v.Name.En).Msg("Failed to generate view")
				return nil
			}
			mu.Lock()
			result[v.Name.En] = viewResp.Content
			mu.Unlock()
			return nil
		})
	}
	_ = g.Wait()

	return json.Marshal(result)
}

func (s *FeedProcessingService) processPostAICalls(ctx context.Context, rawPost domain.RawPost, views []domain.View, feedID uuid.UUID) (*domain.Post, error) {
	var (
		postViews json.RawMessage
		title     = rawPost.Title
	)

	g, gctx := errgroup.WithContext(ctx)

	g.Go(func() error {
		v, err := s.generatePostViewsParallel(gctx, rawPost, views)
		if err != nil {
			return fmt.Errorf("generate views: %w", err)
		}
		postViews = v
		return nil
	})

	if rawPost.Content != "" {
		g.Go(func() error {
			titleResp, err := s.agentsClient.GeneratePostTitle(gctx, rawPost.Content, nil, "")
			if err != nil {
				log.Warn().Err(err).Str("raw_post_id", rawPost.ID.String()).Msg("Failed to generate AI title, using raw title")
				return nil
			}
			title = &titleResp.Title
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return nil, err
	}

	rawPostID := rawPost.ID
	post := &domain.Post{
		ID:                        uuid.New(),
		CreatedAt:                 rawPost.CreatedAt,
		FeedID:                    feedID,
		RawPostID:                 &rawPostID,
		Title:                     title,
		MediaObjects:              rawPost.MediaObjects,
		Views:                     postViews,
		ModerationAction:          rawPost.ModerationAction,
		ModerationLabels:          rawPost.ModerationLabels,
		ModerationMatchedEntities: rawPost.ModerationMatchedEntities,
	}

	var mediaObjects []domain.MediaObject
	if err := json.Unmarshal(rawPost.MediaObjects, &mediaObjects); err == nil {
		var videoPreview *string
		for _, mo := range mediaObjects {
			if mo.Type == "photo" || mo.Type == "image" {
				post.ImageURL = &mo.URL
				break
			}
			if (mo.Type == "video" || mo.Type == "animation") && mo.PreviewURL != nil && videoPreview == nil {
				videoPreview = mo.PreviewURL
			}
		}
		if post.ImageURL == nil && videoPreview != nil {
			post.ImageURL = videoPreview
		}
	}

	return post, nil
}
