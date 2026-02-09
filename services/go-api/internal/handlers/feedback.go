package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/pkg/storage"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

const (
	maxImageSize  = 10 << 20 // 10MB
	maxImages     = 5
	maxFormMemory = 32 << 20 // 32MB
)

var allowedMIMETypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

type FeedbackHandler struct {
	feedbackRepo     *repository.FeedbackRepository
	userRepo         *repository.UserRepository
	usersFeedRepo    *repository.UsersFeedRepository
	s3Client         *storage.S3Client
	telegramBotToken string
	telegramChatID   string
	telegramThreadID int
	s3Bucket         string
	s3PublicURL      string
}

func NewFeedbackHandler(
	feedbackRepo *repository.FeedbackRepository,
	userRepo *repository.UserRepository,
	usersFeedRepo *repository.UsersFeedRepository,
	s3Client *storage.S3Client,
	telegramBotToken string,
	telegramChatID string,
	telegramThreadID int,
	s3Bucket string,
	s3PublicURL string,
) *FeedbackHandler {
	return &FeedbackHandler{
		feedbackRepo:     feedbackRepo,
		userRepo:         userRepo,
		usersFeedRepo:    usersFeedRepo,
		s3Client:         s3Client,
		telegramBotToken: telegramBotToken,
		telegramChatID:   telegramChatID,
		telegramThreadID: telegramThreadID,
		s3Bucket:         s3Bucket,
		s3PublicURL:      s3PublicURL,
	}
}

func (h *FeedbackHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.SubmitFeedback)
	return r
}

func (h *FeedbackHandler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if err := r.ParseMultipartForm(maxFormMemory); err != nil {
		http.Error(w, "invalid multipart form", http.StatusBadRequest)
		return
	}

	message := strings.TrimSpace(r.FormValue("message"))

	var files []*multipart.FileHeader
	if r.MultipartForm != nil && r.MultipartForm.File["images"] != nil {
		files = r.MultipartForm.File["images"]
	}

	if message == "" && len(files) == 0 {
		http.Error(w, "message or images required", http.StatusBadRequest)
		return
	}

	if len(files) > maxImages {
		http.Error(w, fmt.Sprintf("too many images, max %d", maxImages), http.StatusBadRequest)
		return
	}

	for _, fh := range files {
		if fh.Size > maxImageSize {
			http.Error(w, fmt.Sprintf("image %s exceeds max size of 10MB", fh.Filename), http.StatusBadRequest)
			return
		}
		ct := fh.Header.Get("Content-Type")
		if _, ok := allowedMIMETypes[ct]; !ok {
			http.Error(w, fmt.Sprintf("invalid image type %s, allowed: JPEG, PNG, WebP", ct), http.StatusBadRequest)
			return
		}
	}

	var imageURLs []string
	for _, fh := range files {
		f, err := fh.Open()
		if err != nil {
			log.Error().Err(err).Str("filename", fh.Filename).Msg("Failed to open uploaded file")
			http.Error(w, "failed to process image", http.StatusInternalServerError)
			return
		}

		ct := fh.Header.Get("Content-Type")
		ext := allowedMIMETypes[ct]
		key := fmt.Sprintf("feedback/%s/%s%s", userID.String(), uuid.New().String(), ext)

		if err := h.s3Client.Upload(r.Context(), h.s3Bucket, key, f, fh.Size, ct); err != nil {
			f.Close()
			log.Error().Err(err).Str("key", key).Msg("Failed to upload image to S3")
			http.Error(w, "failed to upload image", http.StatusInternalServerError)
			return
		}
		f.Close()

		publicURL := fmt.Sprintf("%s/%s/%s", h.s3PublicURL, h.s3Bucket, key)
		imageURLs = append(imageURLs, publicURL)
	}

	var msgPtr *string
	if message != "" {
		msgPtr = &message
	}

	feedback, err := h.feedbackRepo.Create(r.Context(), repository.CreateFeedbackParams{
		UserID:    userID,
		Message:   msgPtr,
		ImageURLs: imageURLs,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create feedback")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if h.telegramBotToken != "" && h.telegramChatID != "" {
		go h.sendTelegramNotification(userID, message, imageURLs)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success":      true,
		"message":      "Feedback received successfully",
		"feedback_id":  feedback.ID.String(),
		"images_count": len(imageURLs),
	})
}

func (h *FeedbackHandler) sendTelegramNotification(userID uuid.UUID, message string, imageURLs []string) {
	ctx := context.Background()

	var userInfo string
	if h.userRepo != nil {
		user, err := h.userRepo.GetByID(ctx, userID)
		if err == nil && user != nil {
			email := "N/A"
			if user.Email != nil {
				email = *user.Email
			}
			userInfo = fmt.Sprintf("\n📧 Email: <code>%s</code>\n📅 Registered: <code>%s</code>", email, user.CreatedAt.Format("2006-01-02"))
		}
	}

	if h.usersFeedRepo != nil {
		count, err := h.usersFeedRepo.CountUserFeeds(ctx, userID)
		if err == nil {
			userInfo += fmt.Sprintf("\n📰 Feeds: <code>%d</code>", count)
		}
	}

	text := fmt.Sprintf("📝 <b>New Feedback</b>\n\n👤 User: <code>%s</code>%s", userID.String(), userInfo)

	if message != "" {
		text += fmt.Sprintf("\n\n💬 Message:\n%s", message)
	}

	if len(imageURLs) > 0 {
		text += fmt.Sprintf("\n\n🖼 Images (%d):", len(imageURLs))
		for i, url := range imageURLs {
			text += fmt.Sprintf("\n%d. %s", i+1, url)
		}
	}

	body := map[string]interface{}{
		"chat_id":    h.telegramChatID,
		"text":       text,
		"parse_mode": "HTML",
	}
	if h.telegramThreadID > 0 {
		body["message_thread_id"] = h.telegramThreadID
	}

	jsonBody, err := json.Marshal(body)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal telegram message")
		return
	}

	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", h.telegramBotToken)
	resp, err := http.Post(url, "application/json", bytes.NewReader(jsonBody))
	if err != nil {
		log.Error().Err(err).Msg("Failed to send telegram notification")
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Warn().Int("status", resp.StatusCode).Msg("Telegram notification failed")
	}
}
