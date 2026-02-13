package nats

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type Publisher struct {
	nc *nats.Conn
}

func NewPublisher(nc *nats.Conn) *Publisher {
	return &Publisher{nc: nc}
}

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

func (p *Publisher) PublishPostCreated(postID, feedID, userID uuid.UUID) error {
	event := PostCreatedEvent{
		EventType: "post.created",
		EventID:   uuid.New(),
		Timestamp: time.Now().UTC(),
		PostID:    postID,
		FeedID:    feedID,
		UserID:    userID,
	}

	data, err := json.Marshal(event)
	if err != nil {
		return err
	}

	if err := p.nc.Publish("post.created", data); err != nil {
		return err
	}

	log.Info().
		Str("post_id", postID.String()).
		Str("feed_id", feedID.String()).
		Str("user_id", userID.String()).
		Msg("Published post.created event")

	return nil
}

func (p *Publisher) PublishFeedInitialSync(feedID, promptID, userID uuid.UUID) error {
	event := map[string]interface{}{
		"feed_id":   feedID.String(),
		"prompt_id": promptID.String(),
		"user_id":   userID.String(),
	}
	data, _ := json.Marshal(event)
	if err := p.nc.Publish("feed.initial_sync", data); err != nil {
		return err
	}

	log.Debug().
		Str("feed_id", feedID.String()).
		Str("prompt_id", promptID.String()).
		Str("user_id", userID.String()).
		Msg("Published feed.initial_sync event")

	return nil
}

func (p *Publisher) PublishFeedCreationFinished(feedID, userID uuid.UUID) error {
	event := FeedCreationFinishedEvent{
		EventType: "feed.creation_finished",
		EventID:   uuid.New(),
		Timestamp: time.Now().UTC(),
		FeedID:    feedID,
		UserID:    userID,
	}

	data, err := json.Marshal(event)
	if err != nil {
		return err
	}

	if err := p.nc.Publish("feed.creation_finished", data); err != nil {
		return err
	}

	log.Debug().
		Str("feed_id", feedID.String()).
		Str("user_id", userID.String()).
		Msg("Published feed.creation_finished event")

	return nil
}
