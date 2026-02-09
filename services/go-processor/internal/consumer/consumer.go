package consumer

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/observability"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/rs/zerolog/log"
)

const (
	// Stream names
	RawPostsStreamName   = "RAW_POSTS"
	DigestsStreamName    = "DIGESTS"
	FeedSyncStreamName   = "FEED_SYNC"
	FeedCreatedStreamName = "FEED_CREATED"

	// Consumer names
	RawPostsConsumerName   = "go-processor-raw-posts"
	DigestsConsumerName    = "go-processor-digests"
	FeedSyncConsumerName   = "go-processor-feed-sync"
	FeedCreatedConsumerName = "go-processor-feed-created"
)

// MessageHandler handles a specific type of NATS message
type MessageHandler interface {
	Handle(ctx context.Context, msg jetstream.Msg) error
}

// RawPostHandler processes raw post events
type RawPostHandler func(ctx context.Context, event domain.RawPostCreatedEvent) error

// DigestHandler processes digest events
type DigestHandler func(ctx context.Context, event domain.DigestScheduledEvent) error

// FeedSyncHandler processes feed sync events
type FeedSyncHandler func(ctx context.Context, event domain.FeedInitialSyncEvent) error

// FeedCreatedHandler processes feed created events
type FeedCreatedHandler func(ctx context.Context, event domain.FeedCreatedEvent) error

// Consumer manages NATS JetStream consumers
type Consumer struct {
	cfg        *config.Config
	natsClient *nats.Client
	consumers  []jetstream.Consumer
	stopCh     chan struct{}
	running    bool
}

func New(cfg *config.Config, natsClient *nats.Client) *Consumer {
	return &Consumer{
		cfg:        cfg,
		natsClient: natsClient,
		stopCh:     make(chan struct{}),
	}
}

// SetupRawPostConsumer creates consumer for posts.new.* subjects
func (c *Consumer) SetupRawPostConsumer(ctx context.Context, handler RawPostHandler) error {
	js := c.natsClient.JetStream()

	// Ensure stream exists
	_, err := c.natsClient.EnsureStream(ctx, RawPostsStreamName,
		[]string{"posts.new.telegram", "posts.new.rss", "posts.new.web"},
		jetstream.WorkQueuePolicy,
		7*24*time.Hour,
	)
	if err != nil {
		return fmt.Errorf("ensure raw posts stream: %w", err)
	}

	// Create or get consumer
	consumerCfg := jetstream.ConsumerConfig{
		Name:          RawPostsConsumerName,
		Durable:       RawPostsConsumerName,
		FilterSubject: "posts.new.*",
		AckPolicy:     jetstream.AckExplicitPolicy,
		AckWait:       time.Duration(c.cfg.NATSConsumerAckWaitSec) * time.Second,
		MaxDeliver:    c.cfg.NATSConsumerMaxDeliver,
		MaxAckPending: c.cfg.NATSConsumerBatchSize * 10,
	}

	consumer, err := js.CreateOrUpdateConsumer(ctx, RawPostsStreamName, consumerCfg)
	if err != nil {
		return fmt.Errorf("create raw posts consumer: %w", err)
	}

	c.consumers = append(c.consumers, consumer)

	// Start consuming
	go c.consume(ctx, consumer, "raw_posts", func(ctx context.Context, msg jetstream.Msg) error {
		var event domain.RawPostCreatedEvent
		if err := json.Unmarshal(msg.Data(), &event); err != nil {
			log.Error().Err(err).Msg("Failed to unmarshal raw post event")
			return err
		}
		return handler(ctx, event)
	})

	log.Info().
		Str("stream", RawPostsStreamName).
		Str("consumer", RawPostsConsumerName).
		Msg("Raw posts consumer started")

	return nil
}

// SetupDigestConsumer creates consumer for digest.execute subject
func (c *Consumer) SetupDigestConsumer(ctx context.Context, handler DigestHandler) error {
	js := c.natsClient.JetStream()

	// Ensure stream exists
	_, err := c.natsClient.EnsureStream(ctx, DigestsStreamName,
		[]string{"digest.pending", "digest.execute"},
		jetstream.LimitsPolicy,
		30*24*time.Hour,
	)
	if err != nil {
		return fmt.Errorf("ensure digests stream: %w", err)
	}

	// Create or get consumer
	consumerCfg := jetstream.ConsumerConfig{
		Name:          DigestsConsumerName,
		Durable:       DigestsConsumerName,
		FilterSubject: "digest.execute",
		AckPolicy:     jetstream.AckExplicitPolicy,
		AckWait:       time.Duration(c.cfg.NATSConsumerAckWaitSec) * time.Second,
		MaxDeliver:    c.cfg.NATSConsumerMaxDeliver,
	}

	consumer, err := js.CreateOrUpdateConsumer(ctx, DigestsStreamName, consumerCfg)
	if err != nil {
		return fmt.Errorf("create digest consumer: %w", err)
	}

	c.consumers = append(c.consumers, consumer)

	go c.consume(ctx, consumer, "digest", func(ctx context.Context, msg jetstream.Msg) error {
		var event domain.DigestScheduledEvent
		if err := json.Unmarshal(msg.Data(), &event); err != nil {
			log.Error().Err(err).Msg("Failed to unmarshal digest event")
			return err
		}
		return handler(ctx, event)
	})

	log.Info().
		Str("stream", DigestsStreamName).
		Str("consumer", DigestsConsumerName).
		Msg("Digest consumer started")

	return nil
}

// SetupFeedSyncConsumer creates consumer for feed.initial_sync subject
func (c *Consumer) SetupFeedSyncConsumer(ctx context.Context, handler FeedSyncHandler) error {
	js := c.natsClient.JetStream()

	// Ensure stream exists
	_, err := c.natsClient.EnsureStream(ctx, FeedSyncStreamName,
		[]string{"feed.initial_sync"},
		jetstream.WorkQueuePolicy,
		7*24*time.Hour,
	)
	if err != nil {
		return fmt.Errorf("ensure feed sync stream: %w", err)
	}

	// Create or get consumer
	consumerCfg := jetstream.ConsumerConfig{
		Name:          FeedSyncConsumerName,
		Durable:       FeedSyncConsumerName,
		FilterSubject: "feed.initial_sync",
		AckPolicy:     jetstream.AckExplicitPolicy,
		AckWait:       5 * time.Minute, // Longer for initial sync
		MaxDeliver:    c.cfg.NATSConsumerMaxDeliver,
	}

	consumer, err := js.CreateOrUpdateConsumer(ctx, FeedSyncStreamName, consumerCfg)
	if err != nil {
		return fmt.Errorf("create feed sync consumer: %w", err)
	}

	c.consumers = append(c.consumers, consumer)

	go c.consumeWithInProgress(ctx, consumer, "feed_sync", func(ctx context.Context, msg jetstream.Msg) error {
		var event domain.FeedInitialSyncEvent
		if err := json.Unmarshal(msg.Data(), &event); err != nil {
			log.Error().Err(err).Msg("Failed to unmarshal feed sync event")
			return err
		}
		return handler(ctx, event)
	})

	log.Info().
		Str("stream", FeedSyncStreamName).
		Str("consumer", FeedSyncConsumerName).
		Msg("Feed sync consumer started")

	return nil
}

// SetupFeedCreatedConsumer creates consumer for feed.created subject
func (c *Consumer) SetupFeedCreatedConsumer(ctx context.Context, handler FeedCreatedHandler) error {
	js := c.natsClient.JetStream()

	// Ensure stream exists
	_, err := c.natsClient.EnsureStream(ctx, FeedCreatedStreamName,
		[]string{"feed.created"},
		jetstream.WorkQueuePolicy,
		7*24*time.Hour,
	)
	if err != nil {
		return fmt.Errorf("ensure feed created stream: %w", err)
	}

	// Create or get consumer
	consumerCfg := jetstream.ConsumerConfig{
		Name:          FeedCreatedConsumerName,
		Durable:       FeedCreatedConsumerName,
		FilterSubject: "feed.created",
		AckPolicy:     jetstream.AckExplicitPolicy,
		AckWait:       time.Duration(c.cfg.NATSConsumerAckWaitSec) * time.Second,
		MaxDeliver:    c.cfg.NATSConsumerMaxDeliver,
	}

	consumer, err := js.CreateOrUpdateConsumer(ctx, FeedCreatedStreamName, consumerCfg)
	if err != nil {
		return fmt.Errorf("create feed created consumer: %w", err)
	}

	c.consumers = append(c.consumers, consumer)

	go c.consume(ctx, consumer, "feed_created", func(ctx context.Context, msg jetstream.Msg) error {
		var event domain.FeedCreatedEvent
		if err := json.Unmarshal(msg.Data(), &event); err != nil {
			log.Error().Err(err).Msg("Failed to unmarshal feed created event")
			return err
		}
		return handler(ctx, event)
	})

	log.Info().
		Str("stream", FeedCreatedStreamName).
		Str("consumer", FeedCreatedConsumerName).
		Msg("Feed created consumer started")

	return nil
}

// consume is the main consumer loop
func (c *Consumer) consume(ctx context.Context, consumer jetstream.Consumer, eventType string, handler func(context.Context, jetstream.Msg) error) {
	c.running = true

	for {
		select {
		case <-c.stopCh:
			return
		case <-ctx.Done():
			return
		default:
		}

		msgs, err := consumer.Fetch(c.cfg.NATSConsumerBatchSize, jetstream.FetchMaxWait(5*time.Second))
		if err != nil {
			if err != context.DeadlineExceeded && err != context.Canceled {
				log.Warn().Err(err).Str("event_type", eventType).Msg("Error fetching messages")
			}
			continue
		}

		for msg := range msgs.Messages() {
			c.processMessage(ctx, msg, eventType, handler)
		}

		if msgs.Error() != nil && msgs.Error() != context.DeadlineExceeded {
			log.Warn().Err(msgs.Error()).Str("event_type", eventType).Msg("Fetch error")
		}
	}
}

// consumeWithInProgress sends periodic in_progress to prevent redelivery
func (c *Consumer) consumeWithInProgress(ctx context.Context, consumer jetstream.Consumer, eventType string, handler func(context.Context, jetstream.Msg) error) {
	c.running = true

	for {
		select {
		case <-c.stopCh:
			return
		case <-ctx.Done():
			return
		default:
		}

		msgs, err := consumer.Fetch(1, jetstream.FetchMaxWait(5*time.Second))
		if err != nil {
			if err != context.DeadlineExceeded && err != context.Canceled {
				log.Warn().Err(err).Str("event_type", eventType).Msg("Error fetching messages")
			}
			continue
		}

		for msg := range msgs.Messages() {
			// Start in_progress ticker
			ticker := time.NewTicker(20 * time.Second)
			done := make(chan struct{})

			go func() {
				for {
					select {
					case <-ticker.C:
						if err := msg.InProgress(); err != nil {
							log.Warn().Err(err).Msg("Failed to send in_progress")
						}
					case <-done:
						return
					}
				}
			}()

			c.processMessage(ctx, msg, eventType, handler)

			close(done)
			ticker.Stop()
		}

		if msgs.Error() != nil && msgs.Error() != context.DeadlineExceeded {
			log.Warn().Err(msgs.Error()).Str("event_type", eventType).Msg("Fetch error")
		}
	}
}

func (c *Consumer) processMessage(ctx context.Context, msg jetstream.Msg, eventType string, handler func(context.Context, jetstream.Msg) error) {
	start := time.Now()
	subject := msg.Subject()

	// Extract request ID from headers
	requestID := ""
	if headers := msg.Headers(); headers != nil {
		requestID = headers.Get("X-Request-ID")
	}

	logger := log.With().
		Str("subject", subject).
		Str("event_type", eventType).
		Str("request_id", requestID).
		Logger()

	logger.Debug().Msg("Processing message")
	observability.IncNATSConsumed(subject)

	err := handler(ctx, msg)
	duration := time.Since(start)
	observability.ObserveProcessingDuration(eventType, duration.Seconds())

	if err != nil {
		logger.Error().
			Err(err).
			Dur("duration", duration).
			Msg("Message processing failed")

		sentry.WithScope(func(scope *sentry.Scope) {
			scope.SetTag("subject", subject)
			scope.SetTag("event_type", eventType)
			if requestID != "" {
				scope.SetTag("request_id", requestID)
			}
			sentry.CaptureException(err)
		})

		if nackErr := msg.Nak(); nackErr != nil {
			logger.Error().Err(nackErr).Msg("Failed to NACK message")
		}
		observability.IncNATSNacked()
		return
	}

	if ackErr := msg.Ack(); ackErr != nil {
		logger.Error().Err(ackErr).Msg("Failed to ACK message")
		return
	}

	observability.IncNATSAcked()
	logger.Info().
		Dur("duration", duration).
		Msg("Message processed successfully")
}

func (c *Consumer) Stop() {
	if !c.running {
		return
	}

	close(c.stopCh)
	c.running = false
	log.Info().Msg("Consumer stopped")
}
