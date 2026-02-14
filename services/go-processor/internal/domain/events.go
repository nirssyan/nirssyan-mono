package domain

import (
	"time"

	"github.com/google/uuid"
)

type RawFeedType string

const (
	RawFeedTypeTelegram RawFeedType = "TELEGRAM"
	RawFeedTypeRSS      RawFeedType = "RSS"
	RawFeedTypeWeb      RawFeedType = "WEB"
)

type FeedType string

const (
	FeedTypeSinglePost FeedType = "SINGLE_POST"
	FeedTypeDigest     FeedType = "DIGEST"
)

// RawPostCreatedEvent - consumed from posts.new.* subjects
type RawPostCreatedEvent struct {
	EventType        string      `json:"event_type"`
	EventID          uuid.UUID   `json:"event_id"`
	Timestamp        time.Time   `json:"timestamp"`
	RawFeedID        uuid.UUID   `json:"raw_feed_id"`
	RawFeedType      RawFeedType `json:"raw_feed_type"`
	RawPostIDs       []uuid.UUID `json:"raw_post_ids"`
	SourceIdentifier string      `json:"source_identifier"`
}

// DigestScheduledEvent - consumed from digest.execute subject
type DigestScheduledEvent struct {
	EventType   string    `json:"event_type"`
	PromptID    uuid.UUID `json:"prompt_id"`
	ScheduledAt time.Time `json:"scheduled_at"`
	Interval    int       `json:"interval_hours"`
}

// FeedInitialSyncEvent - consumed from feed.initial_sync subject
type FeedInitialSyncEvent struct {
	EventType string    `json:"event_type"`
	EventID   uuid.UUID `json:"event_id"`
	Timestamp time.Time `json:"timestamp"`
	FeedID    uuid.UUID `json:"feed_id"`
	PromptID  uuid.UUID `json:"prompt_id"`
	UserID    uuid.UUID `json:"user_id"`
}

// FeedUpdatedEvent - consumed from feed.updated subject
type FeedUpdatedEvent struct {
	EventType  string           `json:"event_type"`
	FeedID     uuid.UUID        `json:"feed_id"`
	PromptID   uuid.UUID        `json:"prompt_id"`
	UserID     uuid.UUID        `json:"user_id"`
	ViewsRaw   []map[string]any `json:"views_raw"`
	FiltersRaw []map[string]any `json:"filters_raw"`
}

// FeedCreatedEvent - consumed from feed.created subject
type FeedCreatedEvent struct {
	EventType   string            `json:"event_type"`
	EventID     uuid.UUID         `json:"event_id"`
	Timestamp   time.Time         `json:"timestamp"`
	FeedID      uuid.UUID         `json:"feed_id"`
	PromptID    uuid.UUID         `json:"prompt_id"`
	UserID      uuid.UUID         `json:"user_id"`
	Sources     []string          `json:"sources"`
	SourceTypes map[string]string `json:"source_types"`
	PromptText  string            `json:"prompt_text"`
	FeedType    string            `json:"feed_type"`
	ViewsRaw    []map[string]any  `json:"views_raw"`
	FiltersRaw  []map[string]any  `json:"filters_raw"`
}
