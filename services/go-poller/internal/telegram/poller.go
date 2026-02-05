package telegram

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/gotd/td/tg"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/moderation"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-poller/repository"
)

const NATSSubjectTelegram = "posts.new.telegram"

// Poller handles background polling of Telegram channels.
type Poller struct {
	cfg              *config.Config
	client           *Client
	rateLimiter      *AdaptiveRateController
	rawFeedRepo      *repository.RawFeedRepository
	rawPostRepo      *repository.RawPostRepository
	natsPublisher    *nats.Publisher
	moderationClient *moderation.Client

	running int32
	stopCh  chan struct{}
	wg      sync.WaitGroup
}

// NewPoller creates a new Telegram poller.
func NewPoller(
	cfg *config.Config,
	client *Client,
	rawFeedRepo *repository.RawFeedRepository,
	rawPostRepo *repository.RawPostRepository,
	natsPublisher *nats.Publisher,
	moderationClient *moderation.Client,
) *Poller {
	var rateLimiter *AdaptiveRateController
	if cfg.TelegramAdaptiveRateEnabled {
		rateLimiter = NewAdaptiveRateController(
			cfg.TelegramBaseRequestDelayMs,
			cfg.TelegramAdaptiveRateMaxMultiplier,
		)
	}

	return &Poller{
		cfg:              cfg,
		client:           client,
		rateLimiter:      rateLimiter,
		rawFeedRepo:      rawFeedRepo,
		rawPostRepo:      rawPostRepo,
		natsPublisher:    natsPublisher,
		moderationClient: moderationClient,
		stopCh:           make(chan struct{}),
	}
}

// Start begins the polling loop.
func (p *Poller) Start(ctx context.Context) {
	if !atomic.CompareAndSwapInt32(&p.running, 0, 1) {
		log.Warn().Msg("Telegram poller already running")
		return
	}

	p.wg.Add(1)
	go p.pollingLoop(ctx)

	log.Info().
		Int("interval_seconds", p.cfg.TelegramPollingIntervalSeconds).
		Int("concurrent_channels", p.cfg.TelegramConcurrentChannels).
		Bool("adaptive_rate", p.cfg.TelegramAdaptiveRateEnabled).
		Msg("Telegram background poller started")
}

// Stop gracefully stops the polling loop.
func (p *Poller) Stop() {
	if !atomic.CompareAndSwapInt32(&p.running, 1, 0) {
		return
	}

	close(p.stopCh)
	p.wg.Wait()

	log.Info().Msg("Telegram background poller stopped")
}

func (p *Poller) pollingLoop(ctx context.Context) {
	defer p.wg.Done()

	ticker := time.NewTicker(time.Duration(p.cfg.TelegramPollingIntervalSeconds) * time.Second)
	defer ticker.Stop()

	p.pollAllChannels(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		case <-p.stopCh:
			return
		case <-ticker.C:
			p.pollAllChannels(ctx)
		}
	}
}

func (p *Poller) pollAllChannels(ctx context.Context) {
	if !p.client.IsConnected() {
		log.Warn().Msg("Telegram client not connected, skipping poll cycle")
		return
	}

	tierIntervals := p.cfg.TelegramTierIntervals()
	feeds, err := p.rawFeedRepo.GetTelegramFeedsDueForPoll(
		ctx,
		tierIntervals,
		p.cfg.TelegramFloodWaitCooldownSeconds,
	)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get Telegram feeds due for poll")
		return
	}

	if len(feeds) == 0 {
		log.Debug().Msg("No Telegram channels to poll")
		return
	}

	log.Info().
		Int("channels", len(feeds)).
		Int("parallel", p.cfg.TelegramConcurrentChannels).
		Msg("Starting Telegram poll cycle")

	semaphore := make(chan struct{}, p.cfg.TelegramConcurrentChannels)
	var wg sync.WaitGroup

	var successCount, errorCount, floodWaitCount, totalPosts int32

	for _, feed := range feeds {
		wg.Add(1)
		go func(feed domain.RawFeed) {
			defer wg.Done()

			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			if p.rateLimiter != nil {
				time.Sleep(p.rateLimiter.CurrentDelay())
			}

			posts, err := p.pollSingleChannel(ctx, feed)
			if err != nil {
				var floodErr *FloodWaitError
				if errors.As(err, &floodErr) {
					atomic.AddInt32(&floodWaitCount, 1)
					p.handleFloodWait(ctx, feed, floodErr)
				} else {
					atomic.AddInt32(&errorCount, 1)
					log.Error().
						Err(err).
						Str("channel", feed.Name).
						Msg("Channel poll failed")
				}
			} else {
				atomic.AddInt32(&successCount, 1)
				atomic.AddInt32(&totalPosts, int32(posts))
				if p.rateLimiter != nil {
					p.rateLimiter.OnSuccess()
				}
			}
		}(feed)
	}

	wg.Wait()

	log.Info().
		Int32("success", successCount).
		Int32("errors", errorCount).
		Int32("flood_wait", floodWaitCount).
		Int32("total_posts", totalPosts).
		Int("total_channels", len(feeds)).
		Msg("Telegram poll cycle complete")
}

func (p *Poller) pollSingleChannel(ctx context.Context, feed domain.RawFeed) (int, error) {
	startTime := time.Now()

	username := ""
	if feed.TelegramUsername != nil && *feed.TelegramUsername != "" {
		username = *feed.TelegramUsername
	} else if feed.SiteURL != nil && *feed.SiteURL != "" {
		username = extractUsername(*feed.SiteURL)
	}

	if username == "" {
		observability.IncFeedsPolled("telegram", "error")
		return 0, fmt.Errorf("feed %s has no telegram username or site URL", feed.Name)
	}

	peer, err := p.client.ResolveUsername(ctx, username)
	if err != nil {
		if updateErr := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, true, err.Error()); updateErr != nil {
			log.Error().Err(updateErr).Msg("Failed to update poll result")
		}
		observability.IncFeedsPolled("telegram", "error")
		return 0, err
	}

	isFirstRun := feed.LastExecution == nil
	limit := p.cfg.TelegramMaxMessagesPerRequest
	if isFirstRun {
		limit = p.cfg.TelegramInitialMessagesCount
	}

	offsetID := 0
	if feed.LastMessageID != nil {
		// LastMessageID is stored as string in database
		var msgID int64
		if _, err := fmt.Sscanf(*feed.LastMessageID, "%d", &msgID); err == nil {
			offsetID = int(msgID)
		}
	}

	messages, err := p.client.GetChatHistory(ctx, peer, limit, offsetID)
	if err != nil {
		if updateErr := p.rawFeedRepo.UpdatePollResult(ctx, feed.ID, 0, true, err.Error()); updateErr != nil {
			log.Error().Err(updateErr).Msg("Failed to update poll result")
		}
		observability.IncFeedsPolled("telegram", "error")
		return 0, err
	}

	if len(messages) == 0 {
		if err := p.rawFeedRepo.UpdateLastExecution(ctx, feed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to update last execution")
		}
		observability.IncFeedsPolled("telegram", "success")
		observability.ObservePollDuration("telegram", string(feed.PollingTier), time.Since(startTime).Seconds())
		return 0, nil
	}

	parsedMessages := p.parseMessages(messages, peer.ChannelID)
	if len(parsedMessages) == 0 {
		if err := p.rawFeedRepo.UpdateLastExecution(ctx, feed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to update last execution")
		}
		observability.IncFeedsPolled("telegram", "success")
		observability.ObservePollDuration("telegram", string(feed.PollingTier), time.Since(startTime).Seconds())
		return 0, nil
	}

	groupedMessages := GroupMediaMessages(parsedMessages)

	rawPostsData := make([]domain.RawPostCreateData, 0, len(groupedMessages))
	for _, msg := range groupedMessages {
		postData := p.messageToRawPostData(msg, feed)
		rawPostsData = append(rawPostsData, postData)
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
			Str("channel", feed.Name).
			Int("checked", len(rawPostsData)).
			Float64("duration", duration).
			Msg("No new messages (all exist)")

		observability.IncFeedsPolled("telegram", "success")
		observability.ObservePollDuration("telegram", string(feed.PollingTier), duration)
		return 0, nil
	}

	for i := range newPosts {
		result := p.checkModeration(ctx, newPosts[i])
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

	var maxMessageID int64
	for _, msg := range parsedMessages {
		if int64(msg.MessageID) > maxMessageID {
			maxMessageID = int64(msg.MessageID)
		}
	}

	if err := p.rawFeedRepo.UpdateTelegramPollMetadata(ctx, feed.ID, &maxMessageID, false, false); err != nil {
		log.Error().Err(err).Msg("Failed to update Telegram poll metadata")
	}

	duration := time.Since(startTime).Seconds()
	log.Info().
		Str("channel", feed.Name).
		Int("new_posts", len(createdIDs)).
		Int("skipped", len(rawPostsData)-len(newPosts)).
		Int64("max_message_id", maxMessageID).
		Float64("duration", duration).
		Msg("✓ Telegram channel polled")

	if len(createdIDs) > 0 {
		sourceIdentifier := username
		if feed.SiteURL != nil {
			sourceIdentifier = *feed.SiteURL
		}
		p.publishNewPostsEvent(ctx, feed.ID, createdIDs, sourceIdentifier)
	}

	observability.IncFeedsPolled("telegram", "success")
	observability.IncPostsCreated("telegram", len(createdIDs))
	observability.IncTelegramMessages(username, len(createdIDs))
	observability.ObservePollDuration("telegram", string(feed.PollingTier), duration)

	return len(createdIDs), nil
}

func (p *Poller) parseMessages(messages []tg.MessageClass, chatID int64) []*Message {
	result := make([]*Message, 0, len(messages))
	for _, msg := range messages {
		parsed := ParseMessage(msg, chatID, p.cfg.TelegramMediaBaseURL)
		if parsed != nil {
			result = append(result, parsed)
		}
	}
	return result
}

func (p *Poller) messageToRawPostData(msg *Message, feed domain.RawFeed) domain.RawPostCreateData {
	mediaObjects := make([]domain.MediaObject, len(msg.MediaObjects))
	for i, mo := range msg.MediaObjects {
		mediaObjects[i] = domain.MediaObject{
			Type: mo.Type,
			URL:  mo.URL,
		}
	}

	messageID := int64(msg.MessageID)

	var sourceURL *string
	if feed.SiteURL != nil && msg.MessageID > 0 {
		fullURL := fmt.Sprintf("%s/%d", *feed.SiteURL, msg.MessageID)
		sourceURL = &fullURL
	} else if feed.SiteURL != nil {
		sourceURL = feed.SiteURL
	}

	return domain.RawPostCreateData{
		Content:           msg.Content,
		RawFeedID:         feed.ID,
		MediaObjects:      mediaObjects,
		RPUniqueCode:      msg.UniqueCode(),
		Title:             &msg.Title,
		MediaGroupID:      msg.MediaGroupID,
		TelegramMessageID: &messageID,
		SourceURL:         sourceURL,
		CreatedAt:         &msg.PublishedAt,
		ModerationAction:  domain.ModerationActionAllow,
		ModerationLabels:  []string{},
	}
}

func (p *Poller) checkModeration(ctx context.Context, post domain.RawPostCreateData) moderation.ModerationResult {
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
		SourceType:  moderation.SourceTypeTelegram,
		SourceURL:   sourceURL,
		Title:       title,
		Text:        post.Content,
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

func (p *Poller) handleFloodWait(ctx context.Context, feed domain.RawFeed, floodErr *FloodWaitError) {
	log.Warn().
		Str("channel", feed.Name).
		Int("wait_seconds", floodErr.Seconds).
		Msg("FloodWait received")

	if p.rateLimiter != nil {
		p.rateLimiter.OnFloodWait(floodErr.Seconds)
		observability.SetTelegramRateMultiplier(p.rateLimiter.Multiplier())
	}

	now := time.Now().UTC()
	if err := p.rawFeedRepo.UpdateFloodWaitAt(ctx, feed.ID, &now); err != nil {
		log.Error().Err(err).Msg("Failed to update flood wait timestamp")
	}

	observability.IncFeedsPolled("telegram", "flood_wait")
	observability.IncTelegramFloodWait(floodErr.Seconds)
}

func (p *Poller) publishNewPostsEvent(ctx context.Context, feedID uuid.UUID, postIDs []uuid.UUID, sourceURL string) {
	if p.natsPublisher == nil || !p.natsPublisher.IsEnabled() {
		return
	}

	event := domain.NewRawPostCreatedEvent(
		feedID,
		domain.RawFeedTypeTelegram,
		postIDs,
		sourceURL,
	)

	if err := p.natsPublisher.Publish(ctx, NATSSubjectTelegram, event); err != nil {
		log.Error().Err(err).Msg("Failed to publish NATS event")
	}
}

// extractUsername extracts username from Telegram URL.
// Supports: https://t.me/username, t.me/username, @username
func extractUsername(url string) string {
	url = trimPrefix(url, "https://")
	url = trimPrefix(url, "http://")
	url = trimPrefix(url, "t.me/")
	url = trimPrefix(url, "@")
	return url
}

func trimPrefix(s, prefix string) string {
	if len(s) >= len(prefix) && s[:len(prefix)] == prefix {
		return s[len(prefix):]
	}
	return s
}
