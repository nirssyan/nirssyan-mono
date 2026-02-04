package telegram

import (
	"testing"
	"time"

	"github.com/gotd/td/tg"
)

func TestExtractTitle(t *testing.T) {
	tests := []struct {
		name     string
		text     string
		expected string
	}{
		{
			name:     "empty text",
			text:     "",
			expected: "Message",
		},
		{
			name:     "single line",
			text:     "Hello World",
			expected: "Hello World",
		},
		{
			name:     "multi line",
			text:     "First Line\nSecond Line\nThird Line",
			expected: "First Line",
		},
		{
			name:     "long title truncated",
			text:     "This is a very long title that exceeds one hundred characters and should be truncated to exactly one hundred characters no more",
			expected: "This is a very long title that exceeds one hundred characters and should be truncated to exactly one",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractTitle(tt.text)
			if result != tt.expected {
				t.Errorf("extractTitle(%q) = %q, want %q", tt.text, result, tt.expected)
			}
		})
	}
}

func TestMessage_UniqueCode(t *testing.T) {
	tests := []struct {
		name     string
		msg      Message
		expected string
	}{
		{
			name: "without media group",
			msg: Message{
				MessageID: 123,
				ChatID:    456,
			},
			expected: "tg_456_123",
		},
		{
			name: "with media group",
			msg: Message{
				MessageID:    123,
				ChatID:       456,
				MediaGroupID: strPtr("789"),
			},
			expected: "tg_456_789",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.msg.UniqueCode()
			if result != tt.expected {
				t.Errorf("UniqueCode() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestParseMessage(t *testing.T) {
	baseURL := "https://media.example.com"
	chatID := int64(123456)

	t.Run("nil message", func(t *testing.T) {
		result := ParseMessage(nil, chatID, baseURL)
		if result != nil {
			t.Error("expected nil for nil message")
		}
	})

	t.Run("empty message service", func(t *testing.T) {
		msg := &tg.MessageEmpty{ID: 1}
		result := ParseMessage(msg, chatID, baseURL)
		if result != nil {
			t.Error("expected nil for MessageEmpty")
		}
	})

	t.Run("text message", func(t *testing.T) {
		msg := &tg.Message{
			ID:      42,
			Message: "Hello\nWorld",
			Date:    int(time.Date(2024, 1, 15, 10, 30, 0, 0, time.UTC).Unix()),
		}

		result := ParseMessage(msg, chatID, baseURL)
		if result == nil {
			t.Fatal("expected non-nil result")
		}

		if result.MessageID != 42 {
			t.Errorf("MessageID = %d, want 42", result.MessageID)
		}

		if result.ChatID != chatID {
			t.Errorf("ChatID = %d, want %d", result.ChatID, chatID)
		}

		if result.Title != "Hello" {
			t.Errorf("Title = %q, want %q", result.Title, "Hello")
		}

		if result.Content != "Hello\nWorld" {
			t.Errorf("Content = %q, want %q", result.Content, "Hello\nWorld")
		}

		if result.MediaGroupID != nil {
			t.Errorf("MediaGroupID = %v, want nil", result.MediaGroupID)
		}
	})

	t.Run("message with grouped id", func(t *testing.T) {
		msg := &tg.Message{
			ID:        42,
			Message:   "Album caption",
			Date:      int(time.Now().Unix()),
			GroupedID: 987654321,
		}

		result := ParseMessage(msg, chatID, baseURL)
		if result == nil {
			t.Fatal("expected non-nil result")
		}

		if result.MediaGroupID == nil {
			t.Fatal("expected non-nil MediaGroupID")
		}

		if *result.MediaGroupID != "987654321" {
			t.Errorf("MediaGroupID = %q, want %q", *result.MediaGroupID, "987654321")
		}
	})
}

func TestGroupMediaMessages(t *testing.T) {
	t.Run("empty slice", func(t *testing.T) {
		result := GroupMediaMessages(nil)
		if len(result) != 0 {
			t.Errorf("expected empty slice, got %d items", len(result))
		}
	})

	t.Run("no groups", func(t *testing.T) {
		messages := []*Message{
			{MessageID: 1, Content: "First"},
			{MessageID: 2, Content: "Second"},
		}

		result := GroupMediaMessages(messages)
		if len(result) != 2 {
			t.Errorf("expected 2 messages, got %d", len(result))
		}
	})

	t.Run("merge album", func(t *testing.T) {
		groupID := "12345"
		now := time.Now()

		messages := []*Message{
			{
				MessageID:    1,
				ChatID:       100,
				Content:      "",
				MediaGroupID: &groupID,
				PublishedAt:  now,
				MediaObjects: []MediaObject{{Type: "photo", URL: "url1"}},
			},
			{
				MessageID:    2,
				ChatID:       100,
				Content:      "Album caption here",
				MediaGroupID: &groupID,
				PublishedAt:  now.Add(time.Second),
				MediaObjects: []MediaObject{{Type: "photo", URL: "url2"}},
			},
			{
				MessageID:    3,
				ChatID:       100,
				Content:      "",
				MediaGroupID: &groupID,
				PublishedAt:  now.Add(2 * time.Second),
				MediaObjects: []MediaObject{{Type: "photo", URL: "url3"}},
			},
			{
				MessageID:   10,
				ChatID:      100,
				Content:     "Standalone message",
				PublishedAt: now.Add(time.Hour),
			},
		}

		result := GroupMediaMessages(messages)
		if len(result) != 2 {
			t.Fatalf("expected 2 messages after grouping, got %d", len(result))
		}

		var album *Message
		for _, m := range result {
			if m.MediaGroupID != nil {
				album = m
				break
			}
		}

		if album == nil {
			t.Fatal("expected to find album message")
		}

		if len(album.MediaObjects) != 3 {
			t.Errorf("expected 3 media objects in album, got %d", len(album.MediaObjects))
		}

		if album.Content != "Album caption here" {
			t.Errorf("expected album content from message with longest text, got %q", album.Content)
		}

		if album.MessageID != 1 {
			t.Errorf("expected album MessageID to be first in group (1), got %d", album.MessageID)
		}
	})

	t.Run("multiple groups", func(t *testing.T) {
		group1 := "111"
		group2 := "222"
		now := time.Now()

		messages := []*Message{
			{MessageID: 1, MediaGroupID: &group1, PublishedAt: now},
			{MessageID: 2, MediaGroupID: &group1, PublishedAt: now},
			{MessageID: 3, MediaGroupID: &group2, PublishedAt: now.Add(time.Hour)},
			{MessageID: 4, MediaGroupID: &group2, PublishedAt: now.Add(time.Hour)},
			{MessageID: 5, PublishedAt: now.Add(2 * time.Hour)},
		}

		result := GroupMediaMessages(messages)
		if len(result) != 3 {
			t.Errorf("expected 3 messages (2 albums + 1 standalone), got %d", len(result))
		}
	})
}

func TestGetLargestPhotoSize(t *testing.T) {
	photo := &tg.Photo{
		Sizes: []tg.PhotoSizeClass{
			&tg.PhotoSize{Type: "s", W: 100, H: 100},
			&tg.PhotoSize{Type: "m", W: 320, H: 320},
			&tg.PhotoSize{Type: "x", W: 800, H: 600},
		},
	}

	w, h := getLargestPhotoSize(photo)
	if w != 800 || h != 600 {
		t.Errorf("expected 800x600, got %dx%d", w, h)
	}
}

func TestGetBestThumbnail(t *testing.T) {
	t.Run("empty", func(t *testing.T) {
		result := getBestThumbnail(nil)
		if result != nil {
			t.Error("expected nil for empty slice")
		}
	})

	t.Run("returns last", func(t *testing.T) {
		thumbs := []tg.PhotoSizeClass{
			&tg.PhotoSize{Type: "s"},
			&tg.PhotoSize{Type: "m"},
			&tg.PhotoSize{Type: "x"},
		}

		result := getBestThumbnail(thumbs)
		if result == nil {
			t.Fatal("expected non-nil result")
		}

		ps, ok := result.(*tg.PhotoSize)
		if !ok {
			t.Fatal("expected *tg.PhotoSize")
		}

		if ps.Type != "x" {
			t.Errorf("expected type 'x', got %q", ps.Type)
		}
	})
}

func TestTrimPrefix(t *testing.T) {
	tests := []struct {
		s        string
		prefix   string
		expected string
	}{
		{"https://t.me/channel", "https://", "t.me/channel"},
		{"t.me/channel", "https://", "t.me/channel"},
		{"@channel", "@", "channel"},
		{"", "prefix", ""},
	}

	for _, tt := range tests {
		result := trimPrefix(tt.s, tt.prefix)
		if result != tt.expected {
			t.Errorf("trimPrefix(%q, %q) = %q, want %q", tt.s, tt.prefix, result, tt.expected)
		}
	}
}

func strPtr(s string) *string {
	return &s
}
