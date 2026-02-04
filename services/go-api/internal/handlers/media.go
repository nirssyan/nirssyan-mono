package handlers

import (
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
	"github.com/rs/zerolog/log"
)

type MediaHandler struct {
	telegramClient *clients.TelegramClient
	s3PublicURL    string
	proxyTimeout   time.Duration
	dbPool         *pgxpool.Pool
}

func NewMediaHandler(
	telegramClient *clients.TelegramClient,
	s3PublicURL string,
	proxyTimeout time.Duration,
	dbPool *pgxpool.Pool,
) *MediaHandler {
	return &MediaHandler{
		telegramClient: telegramClient,
		s3PublicURL:    s3PublicURL,
		proxyTimeout:   proxyTimeout,
		dbPool:         dbPool,
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

// isMTProtoFileID checks if file_id is in MTProto format (id_accessHash).
// Bot API file_ids are base64 encoded and contain letters.
func isMTProtoFileID(fileID string) bool {
	// MTProto format: {id}_{accessHash} where both are integers
	// Example: "1234567890_9876543210"
	// Bot API format: base64 encoded, starts with letters like "AgACAgI..."
	parts := strings.Split(fileID, "_")
	if len(parts) != 2 {
		return false
	}
	// Check if both parts are valid integers
	if _, err := strconv.ParseInt(parts[0], 10, 64); err != nil {
		return false
	}
	if _, err := strconv.ParseInt(parts[1], 10, 64); err != nil {
		return false
	}
	return true
}

func (h *MediaHandler) GetTelegramMedia(w http.ResponseWriter, r *http.Request) {
	fileID := chi.URLParam(r, "file_id")
	fileType := chi.URLParam(r, "type")
	if fileID == "" {
		http.Error(w, "file_id is required", http.StatusBadRequest)
		return
	}

	// Parse query params for chat_id and msg_id
	var chatID int64
	var msgID int
	if chatStr := r.URL.Query().Get("chat"); chatStr != "" {
		chatID, _ = strconv.ParseInt(chatStr, 10, 64)
	}
	if msgStr := r.URL.Query().Get("msg"); msgStr != "" {
		msgID, _ = strconv.Atoi(msgStr)
	}

	// Strip query params from fileID if present
	if idx := strings.Index(fileID, "?"); idx != -1 {
		fileID = fileID[:idx]
	}

	ctx, cancel := context.WithTimeout(r.Context(), h.proxyTimeout)
	defer cancel()

	if h.telegramClient == nil {
		http.Error(w, "telegram not configured", http.StatusNotFound)
		return
	}

	// Check file_id format: MTProto (id_accessHash) vs Bot API (base64)
	// For Bot API file_ids, try Bot API first, then fallback to MTProto refetch
	if !isMTProtoFileID(fileID) {
		log.Info().Str("file_id", fileID[:min(30, len(fileID))]).Msg("Bot API file_id detected")
		h.serveTelegramFileViaBotAPI(ctx, w, fileID, fileType, chatID, msgID)
		return
	}

	log.Info().Str("file_id", fileID[:min(30, len(fileID))]).Msg("MTProto file_id detected, using NATS")

	// Try to get file via NATS (MTProto) - only for MTProto format file_ids
	data, mimeType, err := h.telegramClient.GetFile(ctx, fileID, fileType, chatID, msgID)
	if err != nil {
		errStr := err.Error()

		// Check for FILE_REFERENCE_EXPIRED error
		if strings.Contains(errStr, "FILE_REFERENCE_EXPIRED") || strings.Contains(errStr, "file reference") {
			log.Warn().Str("file_id", fileID).Msg("FILE_REFERENCE_EXPIRED detected, attempting refresh")

			// Try to refresh file reference
			refreshedData, refreshedMime, refreshErr := h.refreshFileReference(ctx, fileID, fileType, chatID, msgID)
			if refreshErr == nil && len(refreshedData) > 0 {
				if refreshedMime != "" {
					w.Header().Set("Content-Type", refreshedMime)
				}
				w.Header().Set("Cache-Control", "public, max-age=3600")
				w.Header().Set("Content-Length", fmt.Sprintf("%d", len(refreshedData)))
				w.WriteHeader(http.StatusOK)
				w.Write(refreshedData)
				return
			}
			log.Warn().Err(refreshErr).Msg("Failed to refresh file reference")
		}

		log.Warn().Err(err).Str("file_id", fileID).Str("file_type", fileType).Int64("chat_id", chatID).Int("msg_id", msgID).Msg("Failed to get file via NATS, trying Bot API")

		// Fallback to Bot API
		fileURL, err := h.telegramClient.GetFileURL(ctx, fileID)
		if err != nil {
			log.Warn().Err(err).Str("file_id", fileID).Msg("Failed to get file from Telegram")
			http.Error(w, "file not found", http.StatusNotFound)
			return
		}

		if h.proxyTelegramFile(ctx, w, fileURL) {
			return
		}
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}

	// Serve file from NATS response
	if mimeType != "" {
		w.Header().Set("Content-Type", mimeType)
	}
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.WriteHeader(http.StatusOK)
	w.Write(data)
}

// serveTelegramFileViaBotAPI downloads and serves a file using Telegram Bot API.
// Used for Bot API file_ids (base64 format from Python/pyrogram).
// If Bot API fails (expired file_id), it will try to refetch via MTProto if chatID/msgID available.
func (h *MediaHandler) serveTelegramFileViaBotAPI(ctx context.Context, w http.ResponseWriter, fileID string, fileType string, chatID int64, msgID int) {
	// First try Bot API directly
	fileURL, err := h.telegramClient.GetFileURL(ctx, fileID)
	if err == nil {
		// Bot API returned URL, fetch the file
		if h.proxyTelegramFile(ctx, w, fileURL) {
			return
		}
	}

	log.Warn().Err(err).Str("file_id", fileID[:min(30, len(fileID))]).Msg("Bot API failed, trying MTProto refetch")

	// Bot API failed (likely expired file_id)
	// Try to refetch via MTProto - refreshFileReference will find chat_id/msg_id from DB if not provided
	data, mimeType, refreshErr := h.refreshFileReference(ctx, fileID, fileType, chatID, msgID)
	if refreshErr == nil && len(data) > 0 {
		log.Info().Str("file_id", fileID[:min(30, len(fileID))]).Msg("Successfully refreshed file via MTProto")
		if mimeType != "" {
			w.Header().Set("Content-Type", mimeType)
		}
		w.Header().Set("Cache-Control", "public, max-age=3600")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
		w.WriteHeader(http.StatusOK)
		w.Write(data)
		return
	}
	log.Warn().Err(refreshErr).Msg("MTProto refetch also failed")

	http.Error(w, "file not found", http.StatusNotFound)
}

// proxyTelegramFile fetches and proxies a file from Telegram URL.
func (h *MediaHandler) proxyTelegramFile(ctx context.Context, w http.ResponseWriter, fileURL string) bool {
	tgReq, err := http.NewRequestWithContext(ctx, http.MethodGet, fileURL, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to create telegram request")
		return false
	}

	tgResp, err := http.DefaultClient.Do(tgReq)
	if err != nil {
		log.Error().Err(err).Msg("Failed to fetch from telegram")
		return false
	}
	defer tgResp.Body.Close()

	if tgResp.StatusCode != http.StatusOK {
		log.Warn().Int("status", tgResp.StatusCode).Msg("Telegram returned non-OK status")
		return false
	}

	contentType := tgResp.Header.Get("Content-Type")
	if contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	contentLength := tgResp.Header.Get("Content-Length")
	if contentLength != "" {
		w.Header().Set("Content-Length", contentLength)
	}
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.WriteHeader(http.StatusOK)
	io.Copy(w, tgResp.Body)
	return true
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
	// Normalize tg:// to tg/
	if strings.HasPrefix(path, "tg://") {
		path = "tg/" + path[5:]
	}

	// Split off query parameters
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

	// Parse tg/type/file_id
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

	// Check file_id format: MTProto (id_accessHash) vs Bot API (base64)
	// For Bot API file_ids, skip NATS and use Bot API directly
	if !isMTProtoFileID(fileID) {
		log.Info().Str("file_id", fileID[:min(30, len(fileID))]).Msg("Bot API file_id detected")
		h.serveTelegramFileViaBotAPI(ctx, w, fileID, fileType, chatID, msgID)
		return
	}

	log.Info().Str("file_id", fileID[:min(30, len(fileID))]).Msg("MTProto file_id detected, using NATS")

	// Try to get file via NATS (MTProto) - only for MTProto format file_ids
	data, mimeType, err := h.telegramClient.GetFile(ctx, fileID, fileType, chatID, msgID)
	if err != nil {
		errStr := err.Error()

		// Check for FILE_REFERENCE_EXPIRED error
		if strings.Contains(errStr, "FILE_REFERENCE_EXPIRED") || strings.Contains(errStr, "file reference") {
			log.Warn().Str("file_id", fileID).Msg("FILE_REFERENCE_EXPIRED detected, attempting refresh")

			refreshedData, refreshedMime, refreshErr := h.refreshFileReference(ctx, fileID, fileType, chatID, msgID)
			if refreshErr == nil && len(refreshedData) > 0 {
				if refreshedMime != "" {
					w.Header().Set("Content-Type", refreshedMime)
				}
				w.Header().Set("Cache-Control", "public, max-age=3600")
				w.Header().Set("Content-Length", fmt.Sprintf("%d", len(refreshedData)))
				w.WriteHeader(http.StatusOK)
				w.Write(refreshedData)
				return
			}
			log.Warn().Err(refreshErr).Msg("Failed to refresh file reference")
		}

		log.Warn().Err(err).Str("file_id", fileID).Str("file_type", fileType).Int64("chat_id", chatID).Int("msg_id", msgID).Msg("Failed to get file via NATS, trying Bot API")

		// Fallback to Bot API
		fileURL, err := h.telegramClient.GetFileURL(ctx, fileID)
		if err != nil {
			log.Warn().Err(err).Str("file_id", fileID).Msg("Failed to get file from Telegram")
			http.Error(w, "file not found", http.StatusNotFound)
			return
		}

		if h.proxyTelegramFile(ctx, w, fileURL) {
			return
		}
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}

	// Serve file from NATS response
	if mimeType != "" {
		w.Header().Set("Content-Type", mimeType)
	}
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.WriteHeader(http.StatusOK)
	w.Write(data)
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

	if h.telegramClient != nil {
		fileURL, err := h.telegramClient.GetFileURL(ctx, decodedFileID)
		if err != nil {
			log.Warn().Err(err).Str("file_id", decodedFileID).Msg("Failed to get file from Telegram")
			http.Error(w, "file not found", http.StatusNotFound)
			return
		}

		tgReq, err := http.NewRequestWithContext(ctx, http.MethodGet, fileURL, nil)
		if err != nil {
			log.Error().Err(err).Msg("Failed to create telegram request")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		tgResp, err := http.DefaultClient.Do(tgReq)
		if err != nil {
			log.Error().Err(err).Msg("Failed to fetch from telegram")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		defer tgResp.Body.Close()

		if tgResp.StatusCode != http.StatusOK {
			http.Error(w, "file not found", http.StatusNotFound)
			return
		}

		contentType := tgResp.Header.Get("Content-Type")
		if contentType != "" {
			w.Header().Set("Content-Type", contentType)
		}
		w.Header().Set("Cache-Control", "public, max-age=3600")
		w.WriteHeader(http.StatusOK)
		io.Copy(w, tgResp.Body)
		return
	}

	http.Error(w, "file not found", http.StatusNotFound)
}
