package telegram

import (
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	"github.com/gotd/td/tg"
)

// Message represents a parsed Telegram message.
type Message struct {
	MessageID    int
	ChatID       int64
	Title        string
	Content      string
	MediaObjects []MediaObject
	PublishedAt  time.Time
	MediaGroupID *string
}

// MediaObject represents media attached to a message.
type MediaObject struct {
	Type       string  `json:"type"`
	URL        string  `json:"url"`
	PreviewURL *string `json:"preview_url,omitempty"`
	MimeType   string  `json:"mime_type"`
	Width      int     `json:"width,omitempty"`
	Height     int     `json:"height,omitempty"`
	Duration   int     `json:"duration,omitempty"`
	FileName   *string `json:"file_name,omitempty"`
}

// UniqueCode returns deduplication code for the message.
// Format: tg_{chatID}_{mediaGroupID} or tg_{chatID}_{messageID}
func (m *Message) UniqueCode() string {
	if m.MediaGroupID != nil {
		return fmt.Sprintf("tg_%d_%s", m.ChatID, *m.MediaGroupID)
	}
	return fmt.Sprintf("tg_%d_%d", m.ChatID, m.MessageID)
}

// ParseMessage converts tg.Message to our Message struct.
func ParseMessage(msg tg.MessageClass, chatID int64, mediaBaseURL string) *Message {
	m, ok := msg.(*tg.Message)
	if !ok {
		return nil
	}

	text := m.Message
	title := extractTitle(text)
	media := extractMedia(m, chatID, mediaBaseURL)

	var mediaGroupID *string
	if m.GroupedID != 0 {
		groupID := fmt.Sprintf("%d", m.GroupedID)
		mediaGroupID = &groupID
	}

	return &Message{
		MessageID:    m.ID,
		ChatID:       chatID,
		Title:        title,
		Content:      text,
		MediaObjects: media,
		PublishedAt:  time.Unix(int64(m.Date), 0).UTC(),
		MediaGroupID: mediaGroupID,
	}
}

// extractTitle extracts title from message text (first line, max 100 runes).
func extractTitle(text string) string {
	if text == "" {
		return "Message"
	}
	lines := strings.SplitN(text, "\n", 2)
	title := lines[0]
	runes := []rune(title)
	if len(runes) > 100 {
		title = string(runes[:100])
	}
	return title
}

// extractMedia extracts media objects from message.
func extractMedia(m *tg.Message, chatID int64, baseURL string) []MediaObject {
	if m.Media == nil {
		return nil
	}

	metadataQuery := fmt.Sprintf("?chat=%d&msg=%d", chatID, m.ID)
	var media []MediaObject

	switch v := m.Media.(type) {
	case *tg.MessageMediaPhoto:
		if photo, ok := v.Photo.(*tg.Photo); ok {
			fileID := buildPhotoFileID(photo)
			mediaURL := fmt.Sprintf("%s/media/tg/photo/%s%s", baseURL, url.PathEscape(fileID), metadataQuery)

			width, height := getLargestPhotoSize(photo)
			media = append(media, MediaObject{
				Type:     "photo",
				URL:      mediaURL,
				MimeType: "image/jpeg",
				Width:    width,
				Height:   height,
			})
		}

	case *tg.MessageMediaDocument:
		if doc, ok := v.Document.(*tg.Document); ok {
			fileID := fmt.Sprintf("%d_%d", doc.ID, doc.AccessHash)

			isVideo := false
			isAnimation := false
			var width, height, duration int
			var fileName *string

			for _, attr := range doc.Attributes {
				switch a := attr.(type) {
				case *tg.DocumentAttributeVideo:
					isVideo = true
					width = a.W
					height = a.H
					duration = int(a.Duration)
				case *tg.DocumentAttributeAnimated:
					isAnimation = true
				case *tg.DocumentAttributeFilename:
					fileName = &a.FileName
				}
			}

			var mediaType string
			var path string
			switch {
			case isAnimation:
				mediaType = "animation"
				path = "tg/animation"
			case isVideo:
				mediaType = "video"
				path = "tg/video"
			default:
				mediaType = "document"
				path = "tg/document"
			}

			mediaURL := fmt.Sprintf("%s/media/%s/%s%s", baseURL, path, url.PathEscape(fileID), metadataQuery)

			obj := MediaObject{
				Type:     mediaType,
				URL:      mediaURL,
				MimeType: doc.MimeType,
				Width:    width,
				Height:   height,
				Duration: duration,
				FileName: fileName,
			}

			// Add preview URL for video/animation from thumbnail
			if (isVideo || isAnimation) && len(doc.Thumbs) > 0 {
				if thumb := getBestThumbnail(doc.Thumbs); thumb != nil {
					thumbID := fmt.Sprintf("thumb_%d_%d", doc.ID, doc.AccessHash)
					previewURL := fmt.Sprintf("%s/media/tg/photo/%s%s", baseURL, url.PathEscape(thumbID), metadataQuery)
					obj.PreviewURL = &previewURL
				}
			}

			media = append(media, obj)
		}
	}

	return media
}

// buildPhotoFileID creates a file ID string from photo.
func buildPhotoFileID(photo *tg.Photo) string {
	return fmt.Sprintf("%d_%d", photo.ID, photo.AccessHash)
}

// getLargestPhotoSize returns dimensions of the largest photo size.
func getLargestPhotoSize(photo *tg.Photo) (width, height int) {
	for _, size := range photo.Sizes {
		switch s := size.(type) {
		case *tg.PhotoSize:
			if s.W > width {
				width = s.W
				height = s.H
			}
		case *tg.PhotoSizeProgressive:
			if s.W > width {
				width = s.W
				height = s.H
			}
		}
	}
	return
}

// getBestThumbnail returns the largest thumbnail.
func getBestThumbnail(thumbs []tg.PhotoSizeClass) tg.PhotoSizeClass {
	if len(thumbs) == 0 {
		return nil
	}
	return thumbs[len(thumbs)-1]
}

// GroupMediaMessages merges messages with same media_group_id into albums.
func GroupMediaMessages(messages []*Message) []*Message {
	if len(messages) == 0 {
		return messages
	}

	grouped := make([]*Message, 0, len(messages))
	mediaGroups := make(map[string][]*Message)

	for _, msg := range messages {
		if msg.MediaGroupID != nil {
			mediaGroups[*msg.MediaGroupID] = append(mediaGroups[*msg.MediaGroupID], msg)
		} else {
			grouped = append(grouped, msg)
		}
	}

	for _, groupMsgs := range mediaGroups {
		// Sort by message ID
		sort.Slice(groupMsgs, func(i, j int) bool {
			return groupMsgs[i].MessageID < groupMsgs[j].MessageID
		})

		// Find message with longest content (usually has caption)
		msgWithText := groupMsgs[0]
		for _, m := range groupMsgs {
			if len(m.Content) > len(msgWithText.Content) {
				msgWithText = m
			}
		}

		// Merge all media
		var allMedia []MediaObject
		for _, m := range groupMsgs {
			allMedia = append(allMedia, m.MediaObjects...)
		}

		first := groupMsgs[0]
		merged := &Message{
			MessageID:    first.MessageID,
			ChatID:       first.ChatID,
			Title:        msgWithText.Title,
			Content:      msgWithText.Content,
			MediaObjects: allMedia,
			PublishedAt:  first.PublishedAt,
			MediaGroupID: first.MediaGroupID,
		}
		grouped = append(grouped, merged)
	}

	// Sort by publish date
	sort.Slice(grouped, func(i, j int) bool {
		return grouped[i].PublishedAt.Before(grouped[j].PublishedAt)
	})

	return grouped
}
