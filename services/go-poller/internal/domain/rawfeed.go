package domain

import (
	"time"

	"github.com/google/uuid"
)

type RawFeedType string

const (
	RawFeedTypeTelegram RawFeedType = "TELEGRAM"
	RawFeedTypeRSS      RawFeedType = "RSS"
	RawFeedTypeWebsite  RawFeedType = "WEBSITE"
	RawFeedTypeYoutube  RawFeedType = "YOUTUBE"
	RawFeedTypeReddit   RawFeedType = "REDDIT"
)

type PollingTier string

const (
	PollingTierHot        PollingTier = "HOT"
	PollingTierWarm       PollingTier = "WARM"
	PollingTierCold       PollingTier = "COLD"
	PollingTierQuarantine PollingTier = "QUARANTINE"
)

type RawFeed struct {
	ID                 uuid.UUID   `json:"id"`
	Name               string      `json:"name"`
	RawType            RawFeedType `json:"raw_type"`
	FeedURL            *string     `json:"feed_url"`
	SiteURL            *string     `json:"site_url"`
	ImageURL           *string     `json:"image_url"`
	TelegramChatID     *int64      `json:"telegram_chat_id"`
	TelegramUsername   *string     `json:"telegram_username"`
	LastExecution      *time.Time  `json:"last_execution"`
	LastPolledAt       *time.Time  `json:"last_polled_at"`
	LastMessageID      *string     `json:"last_message_id"`
	PollErrorCount     int         `json:"poll_error_count"`
	PollingTier        PollingTier `json:"polling_tier"`
	PriorityBoostUntil *time.Time  `json:"priority_boost_until"`
	LastFloodWaitAt    *time.Time  `json:"last_flood_wait_at"`
	CreatedAt          time.Time   `json:"created_at"`
}

type RawFeedPollResult struct {
	FeedID        uuid.UUID
	NewPostsCount int
	Error         bool
	ErrorMessage  string
}
