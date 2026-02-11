package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// RawPost represents a raw post from source (Telegram, RSS, Web)
type RawPost struct {
	ID                       uuid.UUID       `json:"id"`
	CreatedAt                time.Time       `json:"created_at"`
	Content                  string          `json:"content"`
	RawFeedID                uuid.UUID       `json:"raw_feed_id"`
	RPUniqueCode             string          `json:"rp_unique_code"`
	Title                    *string         `json:"title"`
	MediaGroupID             *string         `json:"media_group_id"`
	TelegramMessageID        *int64          `json:"telegram_message_id"`
	MediaObjects             json.RawMessage `json:"media_objects"`
	SourceURL                *string         `json:"source_url"`
	ModerationAction         *string         `json:"moderation_action"`
	ModerationLabels         []string        `json:"moderation_labels"`
	ModerationBlockReasons   []string        `json:"moderation_block_reasons"`
	ModerationCheckedAt      *time.Time      `json:"moderation_checked_at"`
	ModerationMatchedEntities json.RawMessage `json:"moderation_matched_entities"`
}

// Post represents a processed post in a user's feed
type Post struct {
	ID                        uuid.UUID       `json:"id"`
	CreatedAt                 time.Time       `json:"created_at"`
	FeedID                    uuid.UUID       `json:"feed_id"`
	ImageURL                  *string         `json:"image_url"`
	Title                     *string         `json:"title"`
	MediaObjects              json.RawMessage `json:"media_objects"`
	Views                     json.RawMessage `json:"views"`
	ModerationAction          *string         `json:"moderation_action"`
	ModerationLabels          []string        `json:"moderation_labels"`
	ModerationMatchedEntities json.RawMessage `json:"moderation_matched_entities"`
}

// Feed represents a user's feed configuration
type Feed struct {
	ID                 uuid.UUID  `json:"id"`
	CreatedAt          time.Time  `json:"created_at"`
	Name               string     `json:"name"`
	Type               string     `json:"type"`
	Description        *string    `json:"description"`
	Tags               []string   `json:"tags"`
	IsMarketplace      bool       `json:"is_marketplace"`
	IsCreatingFinished bool       `json:"is_creating_finished"`
	ChatID             *uuid.UUID `json:"chat_id"`
}

// Prompt represents AI processing configuration for a feed
type Prompt struct {
	ID              uuid.UUID       `json:"id"`
	FeedID          uuid.UUID       `json:"feed_id"`
	FeedType        string          `json:"feed_type"`
	ViewsConfig     json.RawMessage `json:"views_config"`
	FiltersConfig   json.RawMessage `json:"filters_config"`
	PrePromptID     *uuid.UUID      `json:"pre_prompt_id"`
	Interval        *int            `json:"interval"`
	LastExecution   *time.Time      `json:"last_execution"`
}

// RawFeed represents a source feed (Telegram channel, RSS, Website)
type RawFeed struct {
	ID        uuid.UUID   `json:"id"`
	Name      string      `json:"name"`
	SourceURL string      `json:"source_url"`
	RawType   RawFeedType `json:"raw_type"`
}

// PromptsRawFeedsOffset tracks processing progress
type PromptsRawFeedsOffset struct {
	PromptID               uuid.UUID  `json:"prompt_id"`
	RawFeedID              uuid.UUID  `json:"raw_feed_id"`
	LastProcessedRawPostID *uuid.UUID `json:"last_processed_raw_post_id"`
}

// Source represents a source link in a post
type Source struct {
	ID        uuid.UUID `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	PostID    uuid.UUID `json:"post_id"`
	SourceURL string    `json:"source_url"`
}

// View represents a view configuration for rendering posts
type View struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

// Filter represents a filter configuration for filtering posts
type Filter struct {
	Name   LocalizedName `json:"name"`
	Prompt string        `json:"prompt"`
}

// LocalizedName for multi-language support
type LocalizedName struct {
	Ru string `json:"ru"`
	En string `json:"en"`
}

// MediaObject represents media attached to a post
type MediaObject struct {
	Type      string  `json:"type"`
	URL       string  `json:"url"`
	PreviewURL *string `json:"preview_url,omitempty"`
	Width     *int    `json:"width,omitempty"`
	Height    *int    `json:"height,omitempty"`
	Duration  *int    `json:"duration,omitempty"`
}
