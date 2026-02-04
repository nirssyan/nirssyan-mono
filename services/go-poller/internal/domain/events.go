package domain

import (
	"time"

	"github.com/google/uuid"
)

type RawPostCreatedEvent struct {
	EventType        string      `json:"event_type"`
	EventID          uuid.UUID   `json:"event_id"`
	Timestamp        time.Time   `json:"timestamp"`
	RawFeedID        uuid.UUID   `json:"raw_feed_id"`
	RawFeedType      RawFeedType `json:"raw_feed_type"`
	RawPostIDs       []uuid.UUID `json:"raw_post_ids"`
	SourceIdentifier string      `json:"source_identifier"`
}

func NewRawPostCreatedEvent(
	rawFeedID uuid.UUID,
	rawFeedType RawFeedType,
	rawPostIDs []uuid.UUID,
	sourceIdentifier string,
) RawPostCreatedEvent {
	return RawPostCreatedEvent{
		EventType:        "raw_post.created",
		EventID:          uuid.New(),
		Timestamp:        time.Now().UTC(),
		RawFeedID:        rawFeedID,
		RawFeedType:      rawFeedType,
		RawPostIDs:       rawPostIDs,
		SourceIdentifier: sourceIdentifier,
	}
}

type WebValidationRequest struct {
	RequestID   uuid.UUID `json:"request_id"`
	URL         string    `json:"url"`
	Lightweight bool      `json:"lightweight"`
}

type WebValidationResponse struct {
	RequestID       uuid.UUID `json:"request_id"`
	Valid           bool      `json:"valid"`
	SourceType      string    `json:"source_type,omitempty"`
	DetectedFeedURL string    `json:"detected_feed_url,omitempty"`
	Error           string    `json:"error,omitempty"`
}
