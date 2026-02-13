package websocket

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type PostCreatedEvent struct {
	EventType string    `json:"event_type"`
	EventID   uuid.UUID `json:"event_id"`
	Timestamp time.Time `json:"timestamp"`
	PostID    uuid.UUID `json:"post_id"`
	FeedID    uuid.UUID `json:"feed_id"`
	UserID    uuid.UUID `json:"user_id"`
}

type FeedCreationFinishedEvent struct {
	EventType string    `json:"event_type"`
	EventID   uuid.UUID `json:"event_id"`
	Timestamp time.Time `json:"timestamp"`
	FeedID    uuid.UUID `json:"feed_id"`
	UserID    uuid.UUID `json:"user_id"`
}

type NotificationConsumer struct {
	manager *Manager
	nc      *nats.Conn
	subs    []*nats.Subscription
}

func NewNotificationConsumer(manager *Manager, nc *nats.Conn) *NotificationConsumer {
	return &NotificationConsumer{
		manager: manager,
		nc:      nc,
	}
}

func (c *NotificationConsumer) Start(ctx context.Context) error {
	postCreatedSub, err := c.nc.Subscribe("post.created", c.handlePostCreated)
	if err != nil {
		return err
	}
	c.subs = append(c.subs, postCreatedSub)
	log.Info().Msg("Subscribed to post.created")

	feedFinishedSub, err := c.nc.Subscribe("feed.creation_finished", c.handleFeedCreationFinished)
	if err != nil {
		return err
	}
	c.subs = append(c.subs, feedFinishedSub)
	log.Info().Msg("Subscribed to feed.creation_finished")

	log.Info().Msg("NotificationConsumer started")
	return nil
}

func (c *NotificationConsumer) Stop() {
	for _, sub := range c.subs {
		if err := sub.Unsubscribe(); err != nil {
			log.Warn().Err(err).Msg("Error unsubscribing")
		}
	}
	log.Info().Msg("NotificationConsumer stopped")
}

func (c *NotificationConsumer) handlePostCreated(msg *nats.Msg) {
	var event PostCreatedEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Error().Err(err).Msg("Error parsing post.created event")
		return
	}

	sentCount := c.manager.NotifyPostCreated(event.UserID, event.PostID, event.FeedID)
	if sentCount > 0 {
		log.Info().
			Str("user_id", event.UserID.String()).
			Str("post_id", event.PostID.String()).
			Str("feed_id", event.FeedID.String()).
			Int("sent_to", sentCount).
			Msg("Sent post_created notification")
	} else {
		log.Info().
			Str("user_id", event.UserID.String()).
			Str("feed_id", event.FeedID.String()).
			Msg("No WebSocket connections for post_created")
	}
}

func (c *NotificationConsumer) handleFeedCreationFinished(msg *nats.Msg) {
	var event FeedCreationFinishedEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Error().Err(err).Msg("Error parsing feed.creation_finished event")
		return
	}

	sentCount := c.manager.NotifyFeedCreationFinished(event.UserID, event.FeedID)
	if sentCount > 0 {
		log.Info().
			Str("user_id", event.UserID.String()).
			Str("feed_id", event.FeedID.String()).
			Int("sent_to", sentCount).
			Msg("Sent feed_creation_finished notification")
	} else {
		log.Info().
			Str("user_id", event.UserID.String()).
			Str("feed_id", event.FeedID.String()).
			Msg("No WebSocket connections for feed_creation_finished")
	}
}
