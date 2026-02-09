package handlers

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/pkg/storage"
	"github.com/rs/zerolog/log"
)

type MediaHandler struct {
	telegramClient *clients.TelegramClient
	s3PublicURL    string
	proxyTimeout   time.Duration
	dbPool         *pgxpool.Pool
	s3Client       *storage.S3Client
	s3Bucket       string
}

func NewMediaHandler(
	telegramClient *clients.TelegramClient,
	s3PublicURL string,
	proxyTimeout time.Duration,
	dbPool *pgxpool.Pool,
	s3Client *storage.S3Client,
	s3Bucket string,
) *MediaHandler {
	return &MediaHandler{
		telegramClient: telegramClient,
		s3PublicURL:    s3PublicURL,
		proxyTimeout:   proxyTimeout,
		dbPool:         dbPool,
		s3Client:       s3Client,
		s3Bucket:       s3Bucket,
	}
}

func (h *MediaHandler) Routes() chi.Router {
	r := chi.NewRouter()

	// More specific route first
	r.Get("/tg/{type}/{file_id}", h.GetTelegramMedia)
	// Catch-all for supabase storage
	r.Get("/*", h.GetMedia)

	return r
}

func (h *MediaHandler) GetTelegramMedia(w http.ResponseWriter, r *http.Request) {
	fileID := chi.URLParam(r, "file_id")
	fileType := chi.URLParam(r, "type")
	if fileID == "" {
		http.Error(w, "file_id is required", http.StatusBadRequest)
		return
	}

	var chatID int64
	var msgID int
	if chatStr := r.URL.Query().Get("chat"); chatStr != "" {
		chatID, _ = strconv.ParseInt(chatStr, 10, 64)
	}
	if msgStr := r.URL.Query().Get("msg"); msgStr != "" {
		msgID, _ = strconv.Atoi(msgStr)
	}

	if idx := strings.Index(fileID, "?"); idx != -1 {
		fileID = fileID[:idx]
	}

	ctx, cancel := context.WithTimeout(r.Context(), h.proxyTimeout)
	defer cancel()

	if h.telegramClient == nil {
		http.Error(w, "telegram not configured", http.StatusNotFound)
		return
	}

	h.serveTelegramFile(ctx, w, fileID, fileType, chatID, msgID)
}

// serveTelegramFile serves media via unified flow: S3 cache → MTProto (NATS) → refresh → write-through.
func (h *MediaHandler) serveTelegramFile(ctx context.Context, w http.ResponseWriter, fileID, fileType string, chatID int64, msgID int) {
	// S3 cache-first
	if h.s3Client != nil {
		s3Key := fmt.Sprintf("%s/%s", fileType, fileID)
		if exists, _ := h.s3Client.Exists(ctx, h.s3Bucket, s3Key); exists {
			reader, err := h.s3Client.Download(ctx, h.s3Bucket, s3Key)
			if err == nil {
				defer reader.Close()
				w.Header().Set("Content-Type", mimeForType(fileType))
				w.Header().Set("Cache-Control", "public, max-age=86400")
				w.WriteHeader(http.StatusOK)
				io.Copy(w, reader)
				return
			}
		}
	}

	// Try MTProto via NATS
	data, mimeType, err := h.telegramClient.GetFile(ctx, fileID, fileType, chatID, msgID)
	if err != nil {
		log.Warn().Err(err).Str("file_id", fileID[:min(30, len(fileID))]).Str("file_type", fileType).Msg("GetFile failed, trying refresh")

		refreshedData, refreshedMime, refreshErr := h.refreshFileReference(ctx, fileID, fileType, chatID, msgID)
		if refreshErr != nil || len(refreshedData) == 0 {
			log.Warn().Err(refreshErr).Str("file_id", fileID[:min(30, len(fileID))]).Msg("Refresh also failed")
			http.Error(w, "file not found", http.StatusNotFound)
			return
		}

		h.writeThroughS3(fileType, fileID, refreshedData, refreshedMime)
		h.serveBytes(w, refreshedData, refreshedMime)
		return
	}

	h.writeThroughS3(fileType, fileID, data, mimeType)
	h.serveBytes(w, data, mimeType)
}

func (h *MediaHandler) serveBytes(w http.ResponseWriter, data []byte, mimeType string) {
	if mimeType != "" {
		w.Header().Set("Content-Type", mimeType)
	}
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.WriteHeader(http.StatusOK)
	w.Write(data)
}


func (h *MediaHandler) refreshFileReference(ctx context.Context, fileID, fileType string, chatID int64, msgID int) ([]byte, string, error) {
	// Try to get metadata from URL params first
	refreshChatID := chatID
	refreshMsgID := msgID

	// If no metadata in URL, search database
	if refreshChatID == 0 || refreshMsgID == 0 {
		log.Debug().Str("file_id", fileID).Msg("No metadata in URL, searching database")
		dbChatID, dbMsgID, err := h.findMetadataInDB(ctx, fileID, fileType)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to find metadata in database")
			return nil, "", fmt.Errorf("no metadata available for file reference refresh")
		}
		refreshChatID = dbChatID
		refreshMsgID = dbMsgID
		log.Info().Int64("chat_id", refreshChatID).Int("msg_id", refreshMsgID).Msg("Found metadata in database")
	}

	// Refetch message to get fresh file_id
	freshFileID, actualMediaType, err := h.telegramClient.RefetchMessage(ctx, refreshChatID, refreshMsgID, fileType)
	if err != nil {
		return nil, "", fmt.Errorf("refetch message: %w", err)
	}

	if freshFileID == "" {
		return nil, "", fmt.Errorf("refetch returned empty file_id")
	}

	log.Info().Str("fresh_file_id", freshFileID[:min(30, len(freshFileID))]).Msg("Got fresh file_id")

	// Retry download with fresh file_id
	data, mimeType, err := h.telegramClient.GetFile(ctx, freshFileID, actualMediaType, refreshChatID, refreshMsgID)
	if err != nil {
		return nil, "", fmt.Errorf("download with fresh file_id: %w", err)
	}

	// Update database with fresh file_id (best effort)
	go func() {
		updateCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := h.updateFileIDInDB(updateCtx, refreshChatID, refreshMsgID, fileID, freshFileID, actualMediaType); err != nil {
			log.Warn().Err(err).Msg("Failed to update file_id in database")
		} else {
			log.Info().Int64("chat_id", refreshChatID).Int("msg_id", refreshMsgID).Msg("Updated file_id in database")
		}
	}()

	return data, mimeType, nil
}

func (h *MediaHandler) findMetadataInDB(ctx context.Context, fileID, mediaType string) (int64, int, error) {
	if h.dbPool == nil {
		return 0, 0, fmt.Errorf("database not configured")
	}

	// Search by file_id directly - URLs in DB may be URL-encoded (tg%2Fphoto%2F vs tg/photo/)
	// So we just search for the file_id itself which is unique
	query := `
		SELECT rp.telegram_message_id, rf.telegram_chat_id
		FROM raw_posts rp
		JOIN raw_feeds rf ON rp.raw_feed_id = rf.id
		WHERE rp.media_objects::text ILIKE $1
		LIMIT 1`

	var msgID int
	var chatID int64

	err := h.dbPool.QueryRow(ctx, query, "%"+fileID+"%").Scan(&msgID, &chatID)
	if err != nil {
		return 0, 0, fmt.Errorf("query database: %w", err)
	}

	return chatID, msgID, nil
}

func (h *MediaHandler) updateFileIDInDB(ctx context.Context, chatID int64, msgID int, oldFileID, freshFileID, mediaType string) error {
	if h.dbPool == nil {
		return fmt.Errorf("database not configured")
	}

	// Find raw_feed_id by chat_id
	var rawFeedID uuid.UUID
	err := h.dbPool.QueryRow(ctx,
		`SELECT id FROM raw_feeds WHERE telegram_chat_id = $1 LIMIT 1`,
		chatID,
	).Scan(&rawFeedID)
	if err != nil {
		return fmt.Errorf("find raw_feed: %w", err)
	}

	// Get raw_post with media_objects
	var rawPostID uuid.UUID
	var mediaObjectsJSON []byte
	err = h.dbPool.QueryRow(ctx,
		`SELECT id, media_objects FROM raw_posts WHERE raw_feed_id = $1 AND telegram_message_id = $2 LIMIT 1`,
		rawFeedID, msgID,
	).Scan(&rawPostID, &mediaObjectsJSON)
	if err != nil {
		return fmt.Errorf("find raw_post: %w", err)
	}

	// Update file_id in media_objects JSON using string replacement
	oldPattern := fmt.Sprintf("tg/%s/%s", mediaType, oldFileID)
	newPattern := fmt.Sprintf("tg/%s/%s", mediaType, freshFileID)
	updatedJSON := strings.ReplaceAll(string(mediaObjectsJSON), oldPattern, newPattern)

	// Also handle legacy tg:// format
	oldPatternLegacy := fmt.Sprintf("tg://%s/%s", mediaType, oldFileID)
	updatedJSON = strings.ReplaceAll(updatedJSON, oldPatternLegacy, newPattern)

	// Update raw_post
	_, err = h.dbPool.Exec(ctx,
		`UPDATE raw_posts SET media_objects = $1::jsonb WHERE id = $2`,
		updatedJSON, rawPostID,
	)
	if err != nil {
		return fmt.Errorf("update raw_post: %w", err)
	}

	return nil
}

func (h *MediaHandler) handleTelegramMediaFromPath(w http.ResponseWriter, r *http.Request, path string) {
	if strings.HasPrefix(path, "tg://") {
		path = "tg/" + path[5:]
	}

	var chatID int64
	var msgID int
	basePath := path
	if idx := strings.Index(path, "?"); idx != -1 {
		basePath = path[:idx]
		queryStr := path[idx+1:]
		for _, param := range strings.Split(queryStr, "&") {
			if strings.HasPrefix(param, "chat=") {
				chatID, _ = strconv.ParseInt(param[5:], 10, 64)
			} else if strings.HasPrefix(param, "msg=") {
				msgID, _ = strconv.Atoi(param[4:])
			}
		}
	}

	parts := strings.SplitN(strings.TrimPrefix(basePath, "tg/"), "/", 2)
	if len(parts) != 2 {
		http.Error(w, "invalid tg path format", http.StatusBadRequest)
		return
	}
	fileType := parts[0]
	fileID := parts[1]

	ctx, cancel := context.WithTimeout(r.Context(), h.proxyTimeout)
	defer cancel()

	if h.telegramClient == nil {
		http.Error(w, "telegram not configured", http.StatusNotFound)
		return
	}

	h.serveTelegramFile(ctx, w, fileID, fileType, chatID, msgID)
}

func (h *MediaHandler) GetMedia(w http.ResponseWriter, r *http.Request) {
	fileID := chi.URLParam(r, "*")
	if fileID == "" {
		http.Error(w, "file_id is required", http.StatusBadRequest)
		return
	}

	// URL-decode the fileID (frontend may send encoded paths like tg%2Fphoto%2F...)
	decodedFileID, err := url.QueryUnescape(fileID)
	if err != nil {
		decodedFileID = fileID
	}

	// Check if this is a Telegram media request (tg/type/file_id format)
	if strings.HasPrefix(decodedFileID, "tg/") || strings.HasPrefix(decodedFileID, "tg://") {
		h.handleTelegramMediaFromPath(w, r, decodedFileID)
		return
	}

	// Strip query params if present
	if idx := strings.Index(decodedFileID, "?"); idx != -1 {
		decodedFileID = decodedFileID[:idx]
	}

	ctx, cancel := context.WithTimeout(r.Context(), h.proxyTimeout)
	defer cancel()

	storageURL := fmt.Sprintf("%s/telegram-media/%s", h.s3PublicURL, decodedFileID)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, storageURL, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create storage request")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Error().Err(err).Msg("Failed to fetch from storage")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		contentType := resp.Header.Get("Content-Type")
		if contentType != "" {
			w.Header().Set("Content-Type", contentType)
		}
		contentLength := resp.Header.Get("Content-Length")
		if contentLength != "" {
			w.Header().Set("Content-Length", contentLength)
		}
		w.Header().Set("Cache-Control", "public, max-age=86400")
		w.WriteHeader(http.StatusOK)
		io.Copy(w, resp.Body)
		return
	}

	http.Error(w, "file not found", http.StatusNotFound)
}

func (h *MediaHandler) writeThroughS3(fileType, fileID string, data []byte, mimeType string) {
	if h.s3Client == nil || len(data) == 0 {
		return
	}
	go func() {
		uploadCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		s3Key := fmt.Sprintf("%s/%s", fileType, fileID)
		if mimeType == "" {
			mimeType = "application/octet-stream"
		}
		if err := h.s3Client.Upload(uploadCtx, h.s3Bucket, s3Key,
			bytes.NewReader(data), int64(len(data)), mimeType); err != nil {
			log.Warn().Err(err).Str("key", s3Key).Msg("Write-through S3 upload failed")
		}
	}()
}

func mimeForType(fileType string) string {
	switch fileType {
	case "photo":
		return "image/jpeg"
	case "video":
		return "video/mp4"
	case "animation":
		return "video/mp4"
	default:
		return "application/octet-stream"
	}
}
