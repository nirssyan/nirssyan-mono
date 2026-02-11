package web

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/web/discovery"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/web/media"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/moderation"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-poller/repository"
	"github.com/rs/zerolog/log"
)

const NATSSubjectWeb = "posts.new.web"

type Poller struct {
	cfg              *config.Config
	httpClient       *http.Client
	pipeline         *discovery.Pipeline
	rawFeedRepo      *repository.RawFeedRepository
	rawPostRepo      *repository.RawPostRepository
	natsPublisher    *nats.Publisher
	moderationClient *moderation.Client

	running int32
	stopCh  chan struct{}
	wg      sync.WaitGroup
}

func NewPoller(
	cfg *config.Config,
	httpClient *http.Client,
	rawFeedRepo *repository.RawFeedRepository,
	rawPostRepo *repository.RawPostRepository,
	natsPublisher *nats.Publisher,
	moderationClient *moderation.Client,
) *Poller {
	return &Poller{
		cfg:              cfg,
		httpClient:       httpClient,
		pipeline:         discovery.NewPipeline(httpClient),
		rawFeedRepo:      rawFeedRepo,
		rawPostRepo:      rawPostRepo,
		natsPublisher:    natsPublisher,
		moderationClient: moderationClient,
		stopCh:           make(chan struct{}),
	}
}

func (p *Poller) Start(ctx context.Context) {
	if !atomic.CompareAndSwapInt32(&p.running, 0, 1) {
		log.Warn().Msg("Web poller already running")
		return
	}

	p.wg.Add(1)
	go p.pollingLoop(ctx)

	log.Info().
		Int("interval_seconds", p.cfg.WebPollingIntervalSeconds).
		Int("concurrent_requests", p.cfg.WebConcurrentRequests).
		Msg("Web background poller started")
}

func (p *Poller) Stop() {
	if !atomic.CompareAndSwapInt32(&p.running, 1, 0) {
		return
	}

	close(p.stopCh)
	p.wg.Wait()

	log.Info().Msg("Web background poller stopped")
}

func (p *Poller) pollingLoop(ctx context.Context) {
	defer p.wg.Done()

	ticker := time.NewTicker(time.Duration(p.cfg.WebPollingIntervalSeconds) * time.Second)
	defer ticker.Stop()

	p.pollAllSources(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		case <-p.stopCh:
			return
		case <-ticker.C:
			p.pollAllSources(ctx)
		}
	}
}

func (p *Poller) pollAllSources(ctx context.Context) {
	tierIntervals := p.cfg.WebTierIntervals()
	feeds, err := p.rawFeedRepo.GetWebFeedsDueForPoll(ctx, tierIntervals)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get web feeds due for poll")
		return
	}

	if len(feeds) == 0 {
		log.Debug().Msg("No web sources to poll")
		return
	}

	log.Info().
		Int("sources", len(feeds)).
		Int("parallel", p.cfg.WebConcurrentRequests).
		Msg("Starting web poll cycle")

	semaphore := make(chan struct{}, p.cfg.WebConcurrentRequests)
	var wg sync.WaitGroup

	var successCount, errorCount, totalPosts int32

	for _, feed := range feeds {
		wg.Add(1)
		go func(feed domain.RawFeed) {
			defer wg.Done()

			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			posts, err := p.pollSingleSource(ctx, feed)
			if err != nil {
				atomic.AddInt32(&errorCount, 1)
				feedURL := ""
				if feed.FeedURL != nil {
					feedURL = *feed.FeedURL
				}
				log.Error().
					Err(err).
					Str("feed", feed.Name).
					Str("url", feedURL).
					Msg("Source poll failed")
			} else {
				atomic.AddInt32(&successCount, 1)
				atomic.AddInt32(&totalPosts, int32(posts))
			}
		}(feed)
	}

	wg.Wait()

	log.Info().
		Int32("success", successCount).
		Int32("errors", errorCount).
		Int32("total_posts", totalPosts).
		Int("total_sources", len(feeds)).
		Msg("Web poll cycle complete")
}

func (p *Poller) pollSingleSource(ctx context.Context, feed domain.RawFeed) (int, error) {
	startTime := time.Now()

	feedCtx, cancel := context.WithTimeout(ctx, p.cfg.WebFeedTimeout)
	defer cancel()

	if feed.FeedURL == nil {
		observability.IncFeedsPolled("web", "error")
		return 0, fmt.Errorf("feed %s has no feed URL", feed.Name)
	}

	feedURL := *feed.FeedURL

	isFirstRun := feed.LastPolledAt == nil
	maxItems := p.cfg.WebMaxArticlesPerRequest
	if isFirstRun {
		maxItems = p.cfg.WebInitialArticlesCount
	}

	result, err := p.pipeline.Discover(feedCtx, feedURL, maxItems, "")
	if err != nil {
		if updateErr := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, true, err.Error()); updateErr != nil {
			log.Error().Err(updateErr).Msg("Failed to update poll result")
		}
		observability.IncFeedsPolled("web", "error")
		return 0, err
	}

	if result == nil || len(result.Articles) == 0 {
		if err := p.rawFeedRepo.UpdateLastExecution(ctx, feed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to update last execution")
		}
		observability.IncFeedsPolled("web", "success")
		observability.ObservePollDuration("web", string(feed.PollingTier), time.Since(startTime).Seconds())
		return 0, nil
	}

	articles := result.Articles
	if p.cfg.HTTPCacheEnabled {
		articles = p.enrichArticlesWithContent(feedCtx, articles, feedURL)
	}

	rawPostsData := make([]domain.RawPostCreateData, 0, len(articles))
	articlesMap := make(map[string]discovery.ArticleMetadata)

	for _, article := range articles {
		if article.URL == "" {
			continue
		}

		postData := p.articleToRawPostData(article, feed.ID)
		rawPostsData = append(rawPostsData, postData)
		articlesMap[postData.RPUniqueCode] = article
	}

	if len(rawPostsData) == 0 {
		if err := p.rawFeedRepo.UpdateLastExecution(ctx, feed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to update last execution")
		}
		return 0, nil
	}

	uniqueCodes := make([]string, len(rawPostsData))
	for i, post := range rawPostsData {
		uniqueCodes[i] = post.RPUniqueCode
	}

	existingCodes, err := p.rawPostRepo.BatchCheckExists(ctx, uniqueCodes)
	if err != nil {
		return 0, err
	}

	newPosts := make([]domain.RawPostCreateData, 0)
	for _, post := range rawPostsData {
		if !existingCodes[post.RPUniqueCode] {
			newPosts = append(newPosts, post)
		}
	}

	if len(newPosts) == 0 {
		if err := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, false, ""); err != nil {
			log.Error().Err(err).Msg("Failed to update poll result")
		}

		duration := time.Since(startTime).Seconds()
		log.Debug().
			Str("feed", feed.Name).
			Int("checked", len(rawPostsData)).
			Float64("duration", duration).
			Msg("No new posts (all exist)")

		observability.IncFeedsPolled("web", "success")
		observability.ObservePollDuration("web", string(feed.PollingTier), duration)
		return 0, nil
	}

	for i := range newPosts {
		article := articlesMap[newPosts[i].RPUniqueCode]
		result := p.checkModeration(ctx, newPosts[i], article)
		newPosts[i].ModerationAction = result.Action
		newPosts[i].ModerationLabels = result.Labels
		newPosts[i].ModerationBlockReasons = result.BlockReasons
		newPosts[i].ModerationCheckedAt = &result.CheckedAt
	}

	createdIDs, err := p.rawPostRepo.BatchCreate(ctx, newPosts)
	if err != nil {
		if updateErr := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, true, err.Error()); updateErr != nil {
			log.Error().Err(updateErr).Msg("Failed to update poll result")
		}
		return 0, err
	}

	if err := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, len(createdIDs), false, ""); err != nil {
		log.Error().Err(err).Msg("Failed to update poll result")
	}

	duration := time.Since(startTime).Seconds()
	log.Info().
		Str("feed", feed.Name).
		Int("new_posts", len(createdIDs)).
		Int("skipped", len(rawPostsData)-len(newPosts)).
		Float64("duration", duration).
		Msg("✓ Web source polled")

	if len(createdIDs) > 0 {
		p.publishNewPostsEvent(ctx, feed.ID, createdIDs, feedURL)
	}

	observability.IncFeedsPolled("web", "success")
	observability.IncPostsCreated("web", len(createdIDs))
	observability.ObservePollDuration("web", string(feed.PollingTier), duration)

	return len(createdIDs), nil
}

func (p *Poller) enrichArticlesWithContent(ctx context.Context, articles []discovery.ArticleMetadata, baseURL string) []discovery.ArticleMetadata {
	enriched := make([]discovery.ArticleMetadata, 0, len(articles))

	for _, article := range articles {
		if article.Content != "" {
			enriched = append(enriched, article)
			continue
		}

		resp, err := p.httpClient.Get(ctx, article.URL)
		if err != nil {
			enriched = append(enriched, article)
			continue
		}

		if resp.StatusCode != 200 {
			enriched = append(enriched, article)
			continue
		}

		html := resp.Text()

		article.MediaURLs = media.ExtractMediaURLs(html, article.URL, true)

		enriched = append(enriched, article)
	}

	return enriched
}

func (p *Poller) articleToRawPostData(article discovery.ArticleMetadata, feedID uuid.UUID) domain.RawPostCreateData {
	content := article.Content
	if content == "" {
		content = article.Summary
	}

	if article.Title != "" && !strings.Contains(content, article.Title) {
		content = fmt.Sprintf("**%s**\n\n%s", article.Title, content)
	}

	mediaObjects := make([]domain.MediaObject, 0)
	for _, url := range article.MediaURLs {
		mediaObjects = append(mediaObjects, domain.NewMediaObject(url))
	}

	uniqueCode := generateUniqueCode(article.URL)

	var title *string
	if article.Title != "" {
		title = &article.Title
	}

	var sourceURL *string
	if article.URL != "" {
		sourceURL = &article.URL
	}

	return domain.RawPostCreateData{
		Content:          content,
		RawFeedID:        feedID,
		MediaObjects:     mediaObjects,
		RPUniqueCode:     uniqueCode,
		Title:            title,
		SourceURL:        sourceURL,
		CreatedAt:        nil,
		ModerationAction: domain.ModerationActionAllow,
		ModerationLabels: []string{},
		ModerationBlockReasons: []string{},
	}
}

func generateUniqueCode(url string) string {
	hash := md5.Sum([]byte(url))
	return hex.EncodeToString(hash[:])
}

func (p *Poller) checkModeration(ctx context.Context, post domain.RawPostCreateData, article discovery.ArticleMetadata) moderation.ModerationResult {
	if p.moderationClient == nil {
		return moderation.ModerationResult{
			Action:    domain.ModerationActionAllow,
			Labels:    []string{},
			CheckedAt: time.Now().UTC(),
		}
	}

	sourceURL := ""
	if post.SourceURL != nil {
		sourceURL = *post.SourceURL
	}

	title := ""
	if post.Title != nil {
		title = *post.Title
	}

	req := moderation.CheckRequest{
		ContentID:  post.RPUniqueCode,
		SourceType: moderation.SourceTypeHTML,
		SourceURL:  sourceURL,
		Title:      title,
		Text:       article.Content,
	}

	resp, err := p.moderationClient.Check(ctx, req)
	if err != nil {
		log.Warn().Err(err).Str("content_id", post.RPUniqueCode).Msg("Moderation check failed")
		return moderation.ModerationResult{
			Action:    domain.ModerationActionAllow,
			Labels:    []string{},
			CheckedAt: time.Now().UTC(),
		}
	}

	return moderation.FromCheckResponse(resp)
}

func (p *Poller) publishNewPostsEvent(ctx context.Context, feedID uuid.UUID, postIDs []uuid.UUID, feedURL string) {
	if p.natsPublisher == nil || !p.natsPublisher.IsEnabled() {
		return
	}

	event := domain.NewRawPostCreatedEvent(
		feedID,
		domain.RawFeedTypeWebsite,
		postIDs,
		feedURL,
	)

	if err := p.natsPublisher.Publish(ctx, NATSSubjectWeb, event); err != nil {
		log.Error().Err(err).Msg("Failed to publish NATS event")
	}
}
