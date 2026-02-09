package telegram

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
)

func TestNewPoller(t *testing.T) {
	cfg := &config.Config{
		TelegramAdaptiveRateEnabled:       true,
		TelegramBaseRequestDelayMs:        100,
		TelegramAdaptiveRateMaxMultiplier: 3.0,
	}

	poller := NewPoller(cfg, nil, nil, nil, nil, nil, nil)

	if poller == nil {
		t.Fatal("expected non-nil poller")
	}

	if poller.rateLimiter == nil {
		t.Error("expected rate limiter to be created when enabled")
	}

	if poller.stopCh == nil {
		t.Error("expected stopCh to be initialized")
	}
}

func TestNewPoller_NoRateLimiter(t *testing.T) {
	cfg := &config.Config{
		TelegramAdaptiveRateEnabled: false,
	}

	poller := NewPoller(cfg, nil, nil, nil, nil, nil, nil)

	if poller.rateLimiter != nil {
		t.Error("expected no rate limiter when disabled")
	}
}

func TestExtractUsername(t *testing.T) {
	tests := []struct {
		url      string
		expected string
	}{
		{"https://t.me/durov", "durov"},
		{"http://t.me/durov", "durov"},
		{"t.me/durov", "durov"},
		{"@durov", "durov"},
		{"durov", "durov"},
		{"https://t.me/channel_name", "channel_name"},
	}

	for _, tt := range tests {
		result := extractUsername(tt.url)
		if result != tt.expected {
			t.Errorf("extractUsername(%q) = %q, want %q", tt.url, result, tt.expected)
		}
	}
}

func TestPoller_MessageToRawPostData(t *testing.T) {
	cfg := &config.Config{}
	poller := &Poller{cfg: cfg}

	siteURL := "https://t.me/testchannel"
	feed := domain.RawFeed{
		ID:      uuid.New(),
		Name:    "Test Channel",
		SiteURL: &siteURL,
	}

	msgTitle := "Test Title"
	groupID := "12345"
	publishedAt := time.Now().UTC()

	msg := &Message{
		MessageID:    42,
		ChatID:       123456,
		Title:        msgTitle,
		Content:      "Test content here",
		MediaGroupID: &groupID,
		PublishedAt:  publishedAt,
		MediaObjects: []MediaObject{
			{Type: "photo", URL: "https://example.com/photo.jpg"},
		},
	}

	result := poller.messageToRawPostData(msg, feed)

	if result.RawFeedID != feed.ID {
		t.Errorf("RawFeedID = %v, want %v", result.RawFeedID, feed.ID)
	}

	if result.Content != "Test content here" {
		t.Errorf("Content = %q, want %q", result.Content, "Test content here")
	}

	if result.Title == nil || *result.Title != msgTitle {
		t.Errorf("Title = %v, want %q", result.Title, msgTitle)
	}

	if result.MediaGroupID == nil || *result.MediaGroupID != groupID {
		t.Errorf("MediaGroupID = %v, want %q", result.MediaGroupID, groupID)
	}

	if result.TelegramMessageID == nil || *result.TelegramMessageID != 42 {
		t.Errorf("TelegramMessageID = %v, want 42", result.TelegramMessageID)
	}

	expectedUniqueCode := "tg_123456_12345"
	if result.RPUniqueCode != expectedUniqueCode {
		t.Errorf("RPUniqueCode = %q, want %q", result.RPUniqueCode, expectedUniqueCode)
	}

	if len(result.MediaObjects) != 1 {
		t.Errorf("expected 1 media object, got %d", len(result.MediaObjects))
	}

	if result.ModerationAction != domain.ModerationActionAllow {
		t.Errorf("ModerationAction = %v, want ALLOW", result.ModerationAction)
	}
}

func TestPoller_IsRunning(t *testing.T) {
	cfg := &config.Config{}
	poller := NewPoller(cfg, nil, nil, nil, nil, nil, nil)

	if poller.running != 0 {
		t.Error("expected poller to not be running initially")
	}
}

func TestFloodWaitError(t *testing.T) {
	err := &FloodWaitError{Seconds: 120}

	expected := "flood wait: need to wait 120 seconds"
	if err.Error() != expected {
		t.Errorf("Error() = %q, want %q", err.Error(), expected)
	}
}

func TestChannelUnavailableError(t *testing.T) {
	err := &ChannelUnavailableError{
		Username: "testchannel",
		Reason:   "private channel",
	}

	expected := "channel @testchannel unavailable: private channel"
	if err.Error() != expected {
		t.Errorf("Error() = %q, want %q", err.Error(), expected)
	}
}

func TestSessionError(t *testing.T) {
	err := &SessionError{
		Op:  "connect",
		Err: ErrSessionExpired,
	}

	if err.Unwrap() != ErrSessionExpired {
		t.Errorf("Unwrap() = %v, want %v", err.Unwrap(), ErrSessionExpired)
	}

	expected := "session connect: telegram session expired"
	if err.Error() != expected {
		t.Errorf("Error() = %q, want %q", err.Error(), expected)
	}
}

func TestNATSSubject(t *testing.T) {
	if NATSSubjectTelegram != "posts.new.telegram" {
		t.Errorf("NATSSubjectTelegram = %q, want %q", NATSSubjectTelegram, "posts.new.telegram")
	}
}
