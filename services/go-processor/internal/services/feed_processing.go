package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
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

// processSinglePostPrompt processes posts for SINGLE_POST feed type
func (s *FeedProcessingService) processSinglePostPrompt(ctx context.Context, prompt domain.Prompt, rawPosts []domain.RawPost, rawFeedID uuid.UUID) error {
	logger := log.With().
		Str("prompt_id", prompt.ID.String()).
		Str("feed_id", prompt.FeedID.String()).
		Logger()

	// Parse filters config to get filter prompt
	filterPrompt, err := s.extractFilterPrompt(prompt.FiltersConfig)
	if err != nil {
		return fmt.Errorf("extract filter prompt: %w", err)
	}

	// Parse views config
	views, err := s.parseViewsConfig(prompt.ViewsConfig)
	if err != nil {
		return fmt.Errorf("parse views config: %w", err)
	}

	createdCount := 0
	var lastProcessedID uuid.UUID

	for _, rawPost := range rawPosts {
		// Skip moderation blocked posts
		if rawPost.ModerationAction != nil && *rawPost.ModerationAction == "block" {
			logger.Debug().
				Str("raw_post_id", rawPost.ID.String()).
				Msg("Skipping blocked post")
			lastProcessedID = rawPost.ID
			continue
		}

		// Evaluate post against filter
		if filterPrompt != "" {
			filterResp, err := s.agentsClient.EvaluatePost(ctx, filterPrompt, rawPost.Content, nil, "")
			if err != nil {
				logger.Error().Err(err).
					Str("raw_post_id", rawPost.ID.String()).
					Msg("Failed to evaluate post")
				continue
			}

			if !filterResp.Result {
				logger.Debug().
					Str("raw_post_id", rawPost.ID.String()).
					Str("explanation", filterResp.Explanation).
					Msg("Post filtered out")
				lastProcessedID = rawPost.ID
				continue
			}
		}

		// Generate views for the post
		postViews, err := s.generatePostViews(ctx, rawPost, views)
		if err != nil {
			logger.Error().Err(err).
				Str("raw_post_id", rawPost.ID.String()).
				Msg("Failed to generate views")
			continue
		}

		// Create post with AI-generated title
		post := s.createPost(ctx, prompt.FeedID, rawPost, postViews)
		sourceURL := ""
		if rawPost.SourceURL != nil {
			sourceURL = *rawPost.SourceURL
		}

		var sourceURLs []string
		if sourceURL != "" {
			sourceURLs = append(sourceURLs, sourceURL)
		}

		if err := s.postRepo.CreatePostWithSources(ctx, post, sourceURLs); err != nil {
			logger.Error().Err(err).
				Str("raw_post_id", rawPost.ID.String()).
				Msg("Failed to create post")
			continue
		}

		observability.IncPostsCreated("SINGLE_POST")
		createdCount++
		lastProcessedID = rawPost.ID

		// Publish post.created event for WebSocket notifications
		if s.publisher != nil {
			userID, err := s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
			if err != nil {
				logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
			} else if userID != uuid.Nil {
				if err := s.publisher.PublishPostCreated(post.ID, prompt.FeedID, userID); err != nil {
					logger.Warn().Err(err).Msg("Failed to publish post.created event")
				}
			}
		}

		// Processing delay
		if s.cfg.ProcessingDelaySeconds > 0 {
			time.Sleep(time.Duration(s.cfg.ProcessingDelaySeconds * float64(time.Second)))
		}
	}

	// Update offset
	if lastProcessedID != uuid.Nil {
		if err := s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, lastProcessedID); err != nil {
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

	// Extract content for summarization
	var contents []string
	for _, p := range allPosts {
		contents = append(contents, p.Content)
	}

	// Extract filter prompt for user_prompt
	filterPrompt, _ := s.extractFilterPrompt(prompt.FiltersConfig)
	if filterPrompt == "" {
		filterPrompt = "Summarize the following posts"
	}

	// Call summary agent
	summaryResp, err := s.agentsClient.SummarizePosts(ctx, filterPrompt, contents, "Digest", nil, "")
	if err != nil {
		return fmt.Errorf("summarize posts: %w", err)
	}

	// Create digest post
	views, _ := s.parseViewsConfig(prompt.ViewsConfig)
	postViews, _ := json.Marshal(map[string]string{
		"default": summaryResp.Summary,
	})

	// Generate additional views
	for _, view := range views {
		viewResp, err := s.agentsClient.GenerateView(ctx, summaryResp.Summary, view.Prompt, nil, "")
		if err != nil {
			logger.Warn().Err(err).Str("view", view.Name.En).Msg("Failed to generate view")
			continue
		}

		var viewsMap map[string]string
		json.Unmarshal(postViews, &viewsMap)
		viewsMap[view.Name.En] = viewResp.Content
		postViews, _ = json.Marshal(viewsMap)
	}

	post := &domain.Post{
		ID:           uuid.New(),
		CreatedAt:    time.Now(),
		FeedID:       prompt.FeedID,
		Title:        &summaryResp.Title,
		MediaObjects: json.RawMessage("[]"),
		Views:        postViews,
	}

	if err := s.postRepo.CreatePost(ctx, post); err != nil {
		return fmt.Errorf("create digest post: %w", err)
	}

	observability.IncPostsCreated("DIGEST")

	// Publish post.created event for WebSocket notifications
	if s.publisher != nil {
		userID, err := s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
		if err != nil {
			logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
		} else if userID != uuid.Nil {
			if err := s.publisher.PublishPostCreated(post.ID, prompt.FeedID, userID); err != nil {
				logger.Warn().Err(err).Msg("Failed to publish post.created event")
			}
		}
	}

	// Update offsets for all raw feeds
	for _, rawFeedID := range rawFeedIDs {
		posts, _ := s.rawPostRepo.GetUnprocessedByPromptAndRawFeed(ctx, prompt.ID, rawFeedID, 1)
		if len(posts) > 0 {
			s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, posts[len(posts)-1].ID)
		}
	}

	// Update last execution
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

	// Transform views and filters if provided
	if len(event.ViewsRaw) > 0 || len(event.FiltersRaw) > 0 {
		var viewsRaw, filtersRaw []string
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
	for _, rawFeedID := range rawFeedIDs {
		// Get recent posts (last 7 days, max from config for filtering)
		since := time.Now().AddDate(0, 0, -7)
		rawPosts, err := s.rawPostRepo.GetRecentByRawFeed(ctx, rawFeedID, since, s.cfg.InitialSyncMaxRawPosts)
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

	createdCount := 0
	var lastProcessedID uuid.UUID

	for _, rawPost := range rawPosts {
		if createdCount >= limit {
			break
		}

		if rawPost.ModerationAction != nil && *rawPost.ModerationAction == "block" {
			logger.Debug().Str("raw_post_id", rawPost.ID.String()).Msg("Skipping blocked post")
			lastProcessedID = rawPost.ID
			continue
		}

		if filterPrompt != "" {
			filterResp, err := s.agentsClient.EvaluatePost(ctx, filterPrompt, rawPost.Content, nil, "")
			if err != nil {
				logger.Error().Err(err).Str("raw_post_id", rawPost.ID.String()).Msg("Failed to evaluate post")
				continue
			}

			if !filterResp.Result {
				logger.Debug().
					Str("raw_post_id", rawPost.ID.String()).
					Str("explanation", filterResp.Explanation).
					Msg("Post filtered out")
				lastProcessedID = rawPost.ID
				continue
			}
		}

		postViews, err := s.generatePostViews(ctx, rawPost, views)
		if err != nil {
			logger.Error().Err(err).Str("raw_post_id", rawPost.ID.String()).Msg("Failed to generate views")
			continue
		}

		post := s.createPost(ctx, prompt.FeedID, rawPost, postViews)
		sourceURL := ""
		if rawPost.SourceURL != nil {
			sourceURL = *rawPost.SourceURL
		}

		var sourceURLs []string
		if sourceURL != "" {
			sourceURLs = append(sourceURLs, sourceURL)
		}

		if err := s.postRepo.CreatePostWithSources(ctx, post, sourceURLs); err != nil {
			logger.Error().Err(err).Str("raw_post_id", rawPost.ID.String()).Msg("Failed to create post")
			continue
		}

		observability.IncPostsCreated("SINGLE_POST")
		createdCount++
		lastProcessedID = rawPost.ID

		if s.publisher != nil {
			userID, err := s.feedRepo.GetFeedOwnerID(ctx, prompt.FeedID)
			if err != nil {
				logger.Warn().Err(err).Msg("Failed to get feed owner for notification")
			} else if userID != uuid.Nil {
				if err := s.publisher.PublishPostCreated(post.ID, prompt.FeedID, userID); err != nil {
					logger.Warn().Err(err).Msg("Failed to publish post.created event")
				}
			}
		}

		if s.cfg.ProcessingDelaySeconds > 0 {
			time.Sleep(time.Duration(s.cfg.ProcessingDelaySeconds * float64(time.Second)))
		}
	}

	if lastProcessedID != uuid.Nil {
		if err := s.offsetRepo.UpdateLastProcessedRawPostID(ctx, prompt.ID, rawFeedID, lastProcessedID); err != nil {
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

func (s *FeedProcessingService) generatePostViews(ctx context.Context, rawPost domain.RawPost, views []domain.View) (json.RawMessage, error) {
	result := map[string]string{
		"default": rawPost.Content,
	}

	for _, view := range views {
		viewResp, err := s.agentsClient.GenerateView(ctx, rawPost.Content, view.Prompt, nil, "")
		if err != nil {
			log.Warn().Err(err).Str("view", view.Name.En).Msg("Failed to generate view")
			continue
		}
		result[view.Name.En] = viewResp.Content
	}

	return json.Marshal(result)
}

func (s *FeedProcessingService) createPost(ctx context.Context, feedID uuid.UUID, rawPost domain.RawPost, views json.RawMessage) *domain.Post {
	// Generate AI title if content available
	title := rawPost.Title
	if rawPost.Content != "" {
		titleResp, err := s.agentsClient.GeneratePostTitle(ctx, rawPost.Content, nil, "")
		if err != nil {
			log.Warn().Err(err).Str("raw_post_id", rawPost.ID.String()).Msg("Failed to generate AI title, using raw title")
		} else {
			title = &titleResp.Title
		}
	}

	post := &domain.Post{
		ID:                        uuid.New(),
		CreatedAt:                 time.Now(),
		FeedID:                    feedID,
		Title:                     title,
		MediaObjects:              rawPost.MediaObjects,
		Views:                     views,
		ModerationAction:          rawPost.ModerationAction,
		ModerationLabels:          rawPost.ModerationLabels,
		ModerationMatchedEntities: rawPost.ModerationMatchedEntities,
	}

	// Extract first image as image_url if available
	var mediaObjects []domain.MediaObject
	if err := json.Unmarshal(rawPost.MediaObjects, &mediaObjects); err == nil {
		for _, mo := range mediaObjects {
			if mo.Type == "photo" || mo.Type == "image" {
				post.ImageURL = &mo.URL
				break
			}
		}
	}

	return post
}
