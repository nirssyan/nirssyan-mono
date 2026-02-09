package telegram

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/gotd/td/tg"
	"github.com/jackc/pgx/v5/pgxpool"
	natsgo "github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

const (
	FileSubject          = "telegram.get_file"
	RefetchMessageSubject = "telegram.refetch_message"
	FileQueue            = "telegram-file-handlers"
)

type FileHandler struct {
	client *Client
	dbPool *pgxpool.Pool
}

func NewFileHandler(client *Client, dbPool *pgxpool.Pool) *FileHandler {
	return &FileHandler{client: client, dbPool: dbPool}
}

type GetFileRequest struct {
	FileID   string `json:"file_id"`
	FileType string `json:"file_type"` // photo, video, document, animation
	ChatID   int64  `json:"chat_id,omitempty"`
	MsgID    int    `json:"msg_id,omitempty"`
}

type GetFileResponse struct {
	Data     string `json:"data,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	Error    string `json:"error,omitempty"`
}

type RefetchMessageRequest struct {
	ChatID    int64  `json:"chat_id"`
	MessageID int    `json:"message_id"`
	MediaType string `json:"media_type"` // photo, video, animation, document
}

type RefetchMessageResponse struct {
	FileID          string `json:"file_id,omitempty"`
	ActualMediaType string `json:"actual_media_type,omitempty"`
	Error           string `json:"error,omitempty"`
}

func (h *FileHandler) Register(nc *natsgo.Conn) error {
	_, err := nc.QueueSubscribe(FileSubject, FileQueue, h.handleRequest)
	if err != nil {
		return err
	}

	_, err = nc.QueueSubscribe(RefetchMessageSubject, FileQueue, h.handleRefetchMessage)
	if err != nil {
		return err
	}

	log.Info().
		Str("subject", FileSubject).
		Str("queue", FileQueue).
		Msg("Registered Telegram file handler")

	log.Info().
		Str("subject", RefetchMessageSubject).
		Str("queue", FileQueue).
		Msg("Registered Telegram refetch message handler")

	return nil
}

func (h *FileHandler) handleRequest(msg *natsgo.Msg) {
	var req GetFileRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		log.Error().Err(err).Msg("Failed to unmarshal file request")
		h.respondWithError(msg, "invalid request format")
		return
	}

	log.Debug().
		Str("file_id", req.FileID).
		Str("file_type", req.FileType).
		Int64("chat_id", req.ChatID).
		Int("msg_id", req.MsgID).
		Msg("Handling Telegram file request")

	ctx := context.Background()
	resp := h.downloadFile(ctx, req)

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal file response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send file response")
	}
}

func (h *FileHandler) downloadFile(ctx context.Context, req GetFileRequest) GetFileResponse {
	return downloadTelegramFile(ctx, h.client, req, h.dbPool)
}

func downloadTelegramFile(ctx context.Context, client *Client, req GetFileRequest, dbPool *pgxpool.Pool) GetFileResponse {
	if client == nil || !client.IsConnected() {
		return GetFileResponse{Error: "telegram client not connected"}
	}

	fileID := req.FileID
	isThumb := strings.HasPrefix(fileID, "thumb_")
	if isThumb {
		fileID = strings.TrimPrefix(fileID, "thumb_")
	}

	// If we have chat_id + msg_id, try message-based download first.
	// This works with any file_id format (pyrogram base64 or id_accessHash).
	if req.ChatID != 0 && req.MsgID != 0 {
		fh := &FileHandler{client: client, dbPool: dbPool}
		data, mimeType, err := fh.downloadViaMessage(ctx, req.ChatID, req.MsgID, 0, req.FileType, isThumb)
		if err == nil {
			return GetFileResponse{
				Data:     base64.StdEncoding.EncodeToString(data),
				MimeType: mimeType,
			}
		}
		log.Warn().Err(err).Msg("downloadViaMessage failed, trying direct download")
	}

	// Parse id_accessHash format for direct download (fallback)
	parts := strings.Split(fileID, "_")
	if len(parts) != 2 {
		return GetFileResponse{Error: fmt.Sprintf("invalid file_id format: %s", req.FileID)}
	}

	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return GetFileResponse{Error: fmt.Sprintf("invalid file id: %v", err)}
	}

	accessHash, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil {
		return GetFileResponse{Error: fmt.Sprintf("invalid access hash: %v", err)}
	}

	var mimeType string
	var location tg.InputFileLocationClass

	switch req.FileType {
	case "photo":
		location = &tg.InputPhotoFileLocation{
			ID:            id,
			AccessHash:    accessHash,
			FileReference: []byte{},
			ThumbSize:     "y",
		}
		mimeType = "image/jpeg"

	case "video", "animation", "document":
		if isThumb {
			location = &tg.InputDocumentFileLocation{
				ID:            id,
				AccessHash:    accessHash,
				FileReference: []byte{},
				ThumbSize:     "m",
			}
			mimeType = "image/jpeg"
		} else {
			location = &tg.InputDocumentFileLocation{
				ID:            id,
				AccessHash:    accessHash,
				FileReference: []byte{},
			}
			mimeType = "application/octet-stream"
		}

	default:
		location = &tg.InputPhotoFileLocation{
			ID:            id,
			AccessHash:    accessHash,
			FileReference: []byte{},
			ThumbSize:     "y",
		}
		mimeType = "image/jpeg"
	}

	data, err := client.DownloadFile(ctx, location)
	if err != nil {
		return GetFileResponse{Error: fmt.Sprintf("download failed: %v", err)}
	}

	return GetFileResponse{
		Data:     base64.StdEncoding.EncodeToString(data),
		MimeType: mimeType,
	}
}

func (h *FileHandler) downloadViaMessage(ctx context.Context, chatID int64, msgID int, photoID int64, fileType string, isThumb bool) ([]byte, string, error) {
	h.client.mu.RLock()
	api := h.client.api
	connected := h.client.connected
	h.client.mu.RUnlock()

	if !connected || api == nil {
		return nil, "", ErrNotConnected
	}

	// Convert chatID to positive channel ID if negative
	channelID := chatID
	if channelID < 0 {
		channelID = -channelID - 1000000000000
	}

	// We need to use InputChannel but we only have the channel ID
	// We'll use messages.getMessages with InputChannel
	var peer *tg.InputPeerChannel

	// Check cache for access hash (populated by the poller when resolving channels)
	h.client.chatCacheMu.RLock()
	for _, cached := range h.client.chatCache {
		if cached.ChannelID == channelID {
			peer = &tg.InputPeerChannel{
				ChannelID:  cached.ChannelID,
				AccessHash: cached.AccessHash,
			}
			break
		}
	}
	h.client.chatCacheMu.RUnlock()

	if peer == nil {
		resolved, err := h.resolveChannelFromDB(ctx, channelID)
		if err != nil {
			return nil, "", fmt.Errorf("channel %d not in cache and DB resolution failed: %w", channelID, err)
		}
		peer = resolved
	}

	// Get the specific message
	result, err := api.MessagesGetHistory(ctx, &tg.MessagesGetHistoryRequest{
		Peer:      peer,
		OffsetID:  msgID + 1,
		Limit:     1,
		AddOffset: 0,
	})
	if err != nil {
		return nil, "", fmt.Errorf("get message: %w", err)
	}

	var messages []tg.MessageClass
	switch v := result.(type) {
	case *tg.MessagesMessages:
		messages = v.Messages
	case *tg.MessagesMessagesSlice:
		messages = v.Messages
	case *tg.MessagesChannelMessages:
		messages = v.Messages
	}

	// Find our specific message
	var targetMsg *tg.Message
	for _, m := range messages {
		if msg, ok := m.(*tg.Message); ok && msg.ID == msgID {
			targetMsg = msg
			break
		}
	}

	if targetMsg == nil {
		return nil, "", fmt.Errorf("message %d not found", msgID)
	}

	// Extract media with fresh file references
	var location tg.InputFileLocationClass
	var mimeType string

	switch media := targetMsg.Media.(type) {
	case *tg.MessageMediaPhoto:
		photo, ok := media.Photo.(*tg.Photo)
		if !ok {
			return nil, "", fmt.Errorf("photo not available")
		}

		// Find the photo size we want
		var bestSize tg.PhotoSizeClass
		for _, size := range photo.Sizes {
			switch s := size.(type) {
			case *tg.PhotoSize:
				if bestSize == nil || s.W > getPhotoWidth(bestSize) {
					bestSize = s
				}
			case *tg.PhotoSizeProgressive:
				if bestSize == nil || s.W > getPhotoWidth(bestSize) {
					bestSize = s
				}
			}
		}

		thumbSize := "y"
		if bestSize != nil {
			thumbSize = getPhotoType(bestSize)
		}

		location = &tg.InputPhotoFileLocation{
			ID:            photo.ID,
			AccessHash:    photo.AccessHash,
			FileReference: photo.FileReference,
			ThumbSize:     thumbSize,
		}
		mimeType = "image/jpeg"

	case *tg.MessageMediaDocument:
		doc, ok := media.Document.(*tg.Document)
		if !ok {
			return nil, "", fmt.Errorf("document not available")
		}

		if isThumb && len(doc.Thumbs) > 0 {
			location = &tg.InputDocumentFileLocation{
				ID:            doc.ID,
				AccessHash:    doc.AccessHash,
				FileReference: doc.FileReference,
				ThumbSize:     "m",
			}
			mimeType = "image/jpeg"
		} else {
			location = &tg.InputDocumentFileLocation{
				ID:            doc.ID,
				AccessHash:    doc.AccessHash,
				FileReference: doc.FileReference,
			}
			mimeType = doc.MimeType
		}

	default:
		return nil, "", fmt.Errorf("unsupported media type: %T", targetMsg.Media)
	}

	data, err := h.client.DownloadFile(ctx, location)
	if err != nil {
		return nil, "", err
	}

	return data, mimeType, nil
}

func getPhotoWidth(size tg.PhotoSizeClass) int {
	switch s := size.(type) {
	case *tg.PhotoSize:
		return s.W
	case *tg.PhotoSizeProgressive:
		return s.W
	}
	return 0
}

func getPhotoType(size tg.PhotoSizeClass) string {
	switch s := size.(type) {
	case *tg.PhotoSize:
		return s.Type
	case *tg.PhotoSizeProgressive:
		return s.Type
	}
	return "y"
}

func (h *FileHandler) respondWithError(msg *natsgo.Msg, errMsg string) {
	resp := GetFileResponse{Error: errMsg}

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal error response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send error response")
	}
}

// handleRefetchMessage handles telegram.refetch_message NATS requests.
// It fetches a message from Telegram and returns the fresh file_id for the media.
func (h *FileHandler) handleRefetchMessage(msg *natsgo.Msg) {
	var req RefetchMessageRequest
	if err := json.Unmarshal(msg.Data, &req); err != nil {
		log.Error().Err(err).Msg("Failed to unmarshal refetch message request")
		h.respondRefetchError(msg, "invalid request format")
		return
	}

	log.Debug().
		Int64("chat_id", req.ChatID).
		Int("message_id", req.MessageID).
		Str("media_type", req.MediaType).
		Msg("Handling refetch message request")

	ctx := context.Background()
	resp := h.refetchMessage(ctx, req)

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal refetch response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send refetch response")
	}
}

func (h *FileHandler) refetchMessage(ctx context.Context, req RefetchMessageRequest) RefetchMessageResponse {
	if h.client == nil || !h.client.IsConnected() {
		return RefetchMessageResponse{Error: "telegram client not connected"}
	}

	h.client.mu.RLock()
	api := h.client.api
	h.client.mu.RUnlock()

	if api == nil {
		return RefetchMessageResponse{Error: "telegram api not available"}
	}

	// Convert chatID to positive channel ID if negative
	channelID := req.ChatID
	if channelID < 0 {
		channelID = -channelID - 1000000000000
	}

	// Find channel in cache
	var peer *tg.InputPeerChannel
	h.client.chatCacheMu.RLock()
	for _, cached := range h.client.chatCache {
		if cached.ChannelID == channelID {
			peer = &tg.InputPeerChannel{
				ChannelID:  cached.ChannelID,
				AccessHash: cached.AccessHash,
			}
			break
		}
	}
	h.client.chatCacheMu.RUnlock()

	if peer == nil {
		resolved, resolveErr := h.resolveChannelFromDB(ctx, channelID)
		if resolveErr != nil {
			return RefetchMessageResponse{Error: fmt.Sprintf("channel %d not in cache and DB resolution failed: %v", channelID, resolveErr)}
		}
		peer = resolved
	}

	// Get the specific message
	result, err := api.MessagesGetHistory(ctx, &tg.MessagesGetHistoryRequest{
		Peer:      peer,
		OffsetID:  req.MessageID + 1,
		Limit:     1,
		AddOffset: 0,
	})
	if err != nil {
		return RefetchMessageResponse{Error: fmt.Sprintf("get message: %v", err)}
	}

	var messages []tg.MessageClass
	switch v := result.(type) {
	case *tg.MessagesMessages:
		messages = v.Messages
	case *tg.MessagesMessagesSlice:
		messages = v.Messages
	case *tg.MessagesChannelMessages:
		messages = v.Messages
	}

	// Find our specific message
	var targetMsg *tg.Message
	for _, m := range messages {
		if msg, ok := m.(*tg.Message); ok && msg.ID == req.MessageID {
			targetMsg = msg
			break
		}
	}

	if targetMsg == nil {
		return RefetchMessageResponse{Error: fmt.Sprintf("message %d not found", req.MessageID)}
	}

	// Extract fresh file_id from media
	var fileID string
	var actualMediaType string

	switch media := targetMsg.Media.(type) {
	case *tg.MessageMediaPhoto:
		photo, ok := media.Photo.(*tg.Photo)
		if !ok {
			return RefetchMessageResponse{Error: "photo not available"}
		}
		fileID = fmt.Sprintf("%d_%d", photo.ID, photo.AccessHash)
		actualMediaType = "photo"

	case *tg.MessageMediaDocument:
		doc, ok := media.Document.(*tg.Document)
		if !ok {
			return RefetchMessageResponse{Error: "document not available"}
		}
		fileID = fmt.Sprintf("%d_%d", doc.ID, doc.AccessHash)

		// Detect document type
		for _, attr := range doc.Attributes {
			switch attr.(type) {
			case *tg.DocumentAttributeAnimated:
				actualMediaType = "animation"
			case *tg.DocumentAttributeVideo:
				if actualMediaType == "" {
					actualMediaType = "video"
				}
			}
		}
		if actualMediaType == "" {
			actualMediaType = "document"
		}

	default:
		return RefetchMessageResponse{Error: fmt.Sprintf("unsupported media type: %T", targetMsg.Media)}
	}

	log.Info().
		Str("file_id", fileID[:min(30, len(fileID))]).
		Str("media_type", actualMediaType).
		Int("message_id", req.MessageID).
		Msg("Refetched fresh file_id")

	return RefetchMessageResponse{
		FileID:          fileID,
		ActualMediaType: actualMediaType,
	}
}

func (h *FileHandler) respondRefetchError(msg *natsgo.Msg, errMsg string) {
	resp := RefetchMessageResponse{Error: errMsg}

	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal refetch error response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send refetch error response")
	}
}

func (h *FileHandler) resolveChannelFromDB(ctx context.Context, channelID int64) (*tg.InputPeerChannel, error) {
	if h.dbPool == nil {
		return nil, fmt.Errorf("no database pool")
	}

	var username string
	err := h.dbPool.QueryRow(ctx,
		"SELECT telegram_username FROM raw_feeds WHERE telegram_chat_id = $1 LIMIT 1",
		channelID,
	).Scan(&username)
	if err != nil {
		negativeID := -1000000000000 - channelID
		err = h.dbPool.QueryRow(ctx,
			"SELECT telegram_username FROM raw_feeds WHERE telegram_chat_id = $1 LIMIT 1",
			negativeID,
		).Scan(&username)
		if err != nil {
			return nil, fmt.Errorf("channel %d not found in DB: %w", channelID, err)
		}
	}

	if username == "" {
		return nil, fmt.Errorf("channel %d has no username in DB", channelID)
	}

	log.Info().Int64("channel_id", channelID).Str("username", username).Msg("Resolving channel from DB")
	return h.client.ResolveUsername(ctx, username)
}

// DownloadFile downloads a file from Telegram using MTProto.
func (c *Client) DownloadFile(ctx context.Context, location tg.InputFileLocationClass) ([]byte, error) {
	c.mu.RLock()
	api := c.api
	connected := c.connected
	c.mu.RUnlock()

	if !connected || api == nil {
		return nil, ErrNotConnected
	}

	const chunkSize = 1024 * 1024 // 1MB chunks
	var data []byte
	var offset int64

	for {
		result, err := api.UploadGetFile(ctx, &tg.UploadGetFileRequest{
			Location: location,
			Offset:   offset,
			Limit:    chunkSize,
		})
		if err != nil {
			if floodErr := extractFloodWait(err); floodErr != nil {
				return nil, floodErr
			}
			return nil, fmt.Errorf("upload.getFile: %w", err)
		}

		file, ok := result.(*tg.UploadFile)
		if !ok {
			return nil, fmt.Errorf("unexpected response type: %T", result)
		}

		data = append(data, file.Bytes...)

		if len(file.Bytes) < chunkSize {
			break
		}

		offset += int64(len(file.Bytes))

		if offset > 50*1024*1024 {
			return nil, fmt.Errorf("file too large (>50MB)")
		}
	}

	return data, nil
}
