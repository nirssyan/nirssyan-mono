package domain

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

type ModerationAction string

const (
	ModerationActionAllow ModerationAction = "ALLOW"
	ModerationActionBlock ModerationAction = "BLOCK"
	ModerationActionFlag  ModerationAction = "FLAG"
)

type MediaObject struct {
	Type       string  `json:"type"`
	URL        string  `json:"url"`
	PreviewURL *string `json:"preview_url,omitempty"`
}

var videoExtensions = []string{".mp4", ".webm", ".ogg", ".mov", ".avi", ".mkv"}

func NewMediaObject(url string) MediaObject {
	urlLower := strings.ToLower(url)
	for _, ext := range videoExtensions {
		if strings.HasSuffix(urlLower, ext) {
			return MediaObject{Type: "video", URL: url}
		}
	}
	return MediaObject{Type: "photo", URL: url}
}

type RawPost struct {
	ID                uuid.UUID        `json:"id"`
	Content           string           `json:"content"`
	RawFeedID         uuid.UUID        `json:"raw_feed_id"`
	MediaObjects      []MediaObject    `json:"media_objects"`
	RPUniqueCode      string           `json:"rp_unique_code"`
	Title             *string          `json:"title,omitempty"`
	MediaGroupID      *string          `json:"media_group_id,omitempty"`
	TelegramMessageID *int64           `json:"telegram_message_id,omitempty"`
	SourceURL         *string          `json:"source_url,omitempty"`
	CreatedAt         *time.Time       `json:"created_at,omitempty"`

	// Moderation fields
	ModerationAction       ModerationAction `json:"moderation_action"`
	ModerationLabels       []string         `json:"moderation_labels"`
	ModerationBlockReasons []string         `json:"moderation_block_reasons"`
	ModerationCheckedAt    *time.Time       `json:"moderation_checked_at,omitempty"`
}

type RawPostCreateData struct {
	Content                string
	RawFeedID              uuid.UUID
	MediaObjects           []MediaObject
	RPUniqueCode           string
	Title                  *string
	MediaGroupID           *string
	TelegramMessageID      *int64
	SourceURL              *string
	CreatedAt              *time.Time
	ModerationAction       ModerationAction
	ModerationLabels       []string
	ModerationBlockReasons []string
	ModerationCheckedAt    *time.Time
}
