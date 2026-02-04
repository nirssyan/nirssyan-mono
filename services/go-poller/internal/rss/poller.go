package rss

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/moderation"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-poller/repository"
	"github.com/rs/zerolog/log"
)

const NATSSubjectRSS = "posts.new.rss"

type Poller struct {
	cfg              *config.Config
	parser           *Parser
	contentEnricher  *ContentEnricher
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
	parser *Parser,
	contentEnricher *ContentEnricher,
	rawFeedRepo *repository.RawFeedRepository,
	rawPostRepo *repository.RawPostRepository,
	natsPublisher *nats.Publisher,
	moderationClient *moderation.Client,
) *Poller {
	return &Poller{
		cfg:              cfg,
		parser:           parser,
		contentEnricher:  contentEnricher,
		rawFeedRepo:      rawFeedRepo,
		rawPostRepo:      rawPostRepo,
		natsPublisher:    natsPublisher,
		moderationClient: moderationClient,
		stopCh:           make(chan struct{}),
	}
}

func (p *Poller) Start(ctx context.Context) {
	if !atomic.CompareAndSwapInt32(&p.running, 0, 1) {
		log.Warn().Msg("RSS poller already running")
		return
	}

	p.wg.Add(1)
	go p.pollingLoop(ctx)

	log.Info().
		Int("interval_seconds", p.cfg.RSSPollingIntervalSeconds).
		Int("concurrent_feeds", p.cfg.RSSConcurrentFeeds).
		Msg("RSS background poller started")
}

func (p *Poller) Stop() {
	if !atomic.CompareAndSwapInt32(&p.running, 1, 0) {
		return
	}

	close(p.stopCh)
	p.wg.Wait()

	log.Info().Msg("RSS background poller stopped")
}

func (p *Poller) pollingLoop(ctx context.Context) {
	defer p.wg.Done()

	ticker := time.NewTicker(time.Duration(p.cfg.RSSPollingIntervalSeconds) * time.Second)
	defer ticker.Stop()

	p.pollAllFeeds(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		case <-p.stopCh:
			return
		case <-ticker.C:
			p.pollAllFeeds(ctx)
		}
	}
}

func (p *Poller) pollAllFeeds(ctx context.Context) {
	tierIntervals := p.cfg.RSSTierIntervals()
	feeds, err := p.rawFeedRepo.GetRSSFeedsDueForPoll(ctx, tierIntervals)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get RSS feeds due for poll")
		return
	}

	if len(feeds) == 0 {
		log.Debug().Msg("No RSS feeds to poll")
		return
	}

	log.Info().
		Int("feeds", len(feeds)).
		Int("parallel", p.cfg.RSSConcurrentFeeds).
		Msg("Starting RSS poll cycle")

	semaphore := make(chan struct{}, p.cfg.RSSConcurrentFeeds)
	var wg sync.WaitGroup

	var successCount, errorCount, totalPosts int32

	for _, feed := range feeds {
		wg.Add(1)
		go func(feed domain.RawFeed) {
			defer wg.Done()

			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			posts, err := p.pollSingleFeed(ctx, feed)
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
					Msg("Feed poll failed")
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
		Int("total_feeds", len(feeds)).
		Msg("RSS poll cycle complete")
}

func (p *Poller) pollSingleFeed(ctx context.Context, feed domain.RawFeed) (int, error) {
	startTime := time.Now()

	feedCtx, cancel := context.WithTimeout(ctx, p.cfg.RSSFeedTimeout)
	defer cancel()

	isFirstRun := feed.LastExecution == nil
	maxItems := p.cfg.RSSMaxArticlesPerRequest
	if isFirstRun {
		maxItems = p.cfg.RSSInitialArticlesCount
	}

	if feed.FeedURL == nil {
		observability.IncFeedsPolled("rss", "error")
		return 0, fmt.Errorf("feed %s has no feed URL", feed.Name)
	}

	items, err := p.parser.ParseFeed(feedCtx, *feed.FeedURL)
	if err != nil {
		if updateErr := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, true, err.Error()); updateErr != nil {
			log.Error().Err(updateErr).Msg("Failed to update poll result")
		}
		observability.IncFeedsPolled("rss", "error")
		return 0, err
	}

	if len(items) == 0 {
		if err := p.rawFeedRepo.UpdateLastExecution(ctx, feed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to update last execution")
		}
		observability.IncFeedsPolled("rss", "success")
		observability.ObservePollDuration("rss", string(feed.PollingTier), time.Since(startTime).Seconds())
		return 0, nil
	}

	if len(items) > maxItems {
		items = items[:maxItems]
	}

	if p.cfg.RSSFetchFullContent {
		for i := range items {
			if err := p.contentEnricher.EnrichItem(feedCtx, &items[i]); err != nil {
				log.Debug().Err(err).Str("url", items[i].Link).Msg("Content enrichment failed")
			}
		}
	}

	rawPostsData := make([]domain.RawPostCreateData, 0, len(items))
	itemsMap := make(map[string]RSSItem)

	for _, item := range items {
		if item.Link == "" {
			continue
		}

		postData := item.ToRawPostData(feed)
		rawPostsData = append(rawPostsData, postData)
		itemsMap[postData.RPUniqueCode] = item
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

		observability.IncFeedsPolled("rss", "success")
		observability.ObservePollDuration("rss", string(feed.PollingTier), duration)
		return 0, nil
	}

	for i := range newPosts {
		item := itemsMap[newPosts[i].RPUniqueCode]
		result := p.checkModeration(ctx, newPosts[i], item)
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
		Msg("✓ RSS feed polled")

	if len(createdIDs) > 0 {
		p.publishNewPostsEvent(ctx, feed.ID, createdIDs, *feed.FeedURL)
	}

	observability.IncFeedsPolled("rss", "success")
	observability.IncPostsCreated("rss", len(createdIDs))
	observability.ObservePollDuration("rss", string(feed.PollingTier), duration)

	return len(createdIDs), nil
}

func (p *Poller) checkModeration(ctx context.Context, post domain.RawPostCreateData, item RSSItem) moderation.ModerationResult {
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
		ContentID:   post.RPUniqueCode,
		SourceType:  moderation.SourceTypeRSS,
		SourceURL:   sourceURL,
		Title:       title,
		Text:        item.Description,
		PublishedAt: post.CreatedAt,
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
		domain.RawFeedTypeRSS,
		postIDs,
		feedURL,
	)

	if err := p.natsPublisher.Publish(ctx, NATSSubjectRSS, event); err != nil {
		log.Error().Err(err).Msg("Failed to publish NATS event")
	}
}
