package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type FeedHandler struct {
	feedRepo         *repository.FeedRepository
	postRepo         *repository.PostRepository
	postSeenRepo     *repository.PostSeenRepository
	usersFeedRepo    *repository.UsersFeedRepository
	promptRepo       *repository.PromptRepository
	prePromptRepo    *repository.PrePromptRepository
	rawFeedRepo      *repository.RawFeedRepository
	rawPostRepo      *repository.RawPostRepository
	subscriptionRepo *repository.SubscriptionRepository
	userRepo         *repository.UserRepository
	suggestionRepo   *repository.SuggestionRepository
	agents           *clients.AgentsClient
	validation       *clients.ValidationClient
	telegram         *clients.TelegramClient
	adminNotify      *clients.AdminNotifyClient
	feedThreadID     int
	nc               *nats.Conn
}

func NewFeedHandler(
	feedRepo *repository.FeedRepository,
	postRepo *repository.PostRepository,
	postSeenRepo *repository.PostSeenRepository,
	usersFeedRepo *repository.UsersFeedRepository,
	promptRepo *repository.PromptRepository,
	prePromptRepo *repository.PrePromptRepository,
	rawFeedRepo *repository.RawFeedRepository,
	rawPostRepo *repository.RawPostRepository,
	subscriptionRepo *repository.SubscriptionRepository,
	userRepo *repository.UserRepository,
	suggestionRepo *repository.SuggestionRepository,
	agents *clients.AgentsClient,
	validation *clients.ValidationClient,
	telegram *clients.TelegramClient,
	adminNotify *clients.AdminNotifyClient,
	feedThreadID int,
	nc *nats.Conn,
) *FeedHandler {
	return &FeedHandler{
		feedRepo:         feedRepo,
		postRepo:         postRepo,
		postSeenRepo:     postSeenRepo,
		usersFeedRepo:    usersFeedRepo,
		promptRepo:       promptRepo,
		prePromptRepo:    prePromptRepo,
		rawFeedRepo:      rawFeedRepo,
		rawPostRepo:      rawPostRepo,
		subscriptionRepo: subscriptionRepo,
		userRepo:         userRepo,
		suggestionRepo:   suggestionRepo,
		agents:           agents,
		validation:       validation,
		telegram:         telegram,
		adminNotify:      adminNotify,
		feedThreadID:     feedThreadID,
		nc:               nc,
	}
}

func (h *FeedHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/", h.GetUserFeeds)
	r.Post("/create", h.CreateFeed)
	r.Patch("/{feed_id}", h.UpdateFeed)
	r.Post("/rename", h.RenameFeed)
	r.Post("/generate_title", h.GenerateTitle)
	r.Post("/read_all/{feed_id}", h.MarkAllRead)
	r.Post("/summarize_unseen/{feed_id}", h.SummarizeUnseen)

	return r
}

type FeedResponse struct {
	ID                 uuid.UUID `json:"id"`
	Name               string    `json:"name"`
	Type               string    `json:"type"`
	Description        *string   `json:"description,omitempty"`
	Tags               []string  `json:"tags"`
	IsMarketplace      bool      `json:"is_marketplace"`
	IsCreatingFinished bool      `json:"is_creating_finished"`
	UnreadCount        int       `json:"unread_count"`
}

func (h *FeedHandler) GetUserFeeds(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feeds, err := h.feedRepo.GetUserFeeds(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get user feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	response := make([]FeedResponse, 0, len(feeds))
	for _, f := range feeds {
		unseenCount, _ := h.postRepo.CountUnseenPosts(r.Context(), userID, f.ID)
		response = append(response, FeedResponse{
			ID:                 f.ID,
			Name:               f.Name,
			Type:               f.Type,
			Description:        f.Description,
			Tags:               f.Tags,
			IsMarketplace:      f.IsMarketplace,
			IsCreatingFinished: f.IsCreatingFinished,
			UnreadCount:        unseenCount,
		})
	}

	writeJSON(w, http.StatusOK, response)
}

type UpdateFeedRequest struct {
	Name                *string       `json:"name,omitempty"`
	Description         *string       `json:"description,omitempty"`
	Tags                []string      `json:"tags,omitempty"`
	Sources             []SourceInput `json:"sources,omitempty"`
	RawPrompt           *string       `json:"raw_prompt,omitempty"`
	ViewsRaw            []string      `json:"views_raw,omitempty"`
	FiltersRaw          []string      `json:"filters_raw,omitempty"`
	DigestIntervalHours *int          `json:"digest_interval_hours,omitempty"`
}

type UpdateFeedResponse struct {
	Success       bool     `json:"success"`
	FeedID        string   `json:"feed_id"`
	Message       string   `json:"message"`
	UpdatedFields []string `json:"updated_fields"`
}

func (h *FeedHandler) UpdateFeed(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := chi.URLParam(r, "feed_id")
	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	var req UpdateFeedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "you don't have access to this feed", http.StatusForbidden)
		return
	}

	updatedFields := []string{}
	if req.Name != nil {
		updatedFields = append(updatedFields, "name")
	}
	if req.Description != nil {
		updatedFields = append(updatedFields, "description")
	}
	if req.Tags != nil {
		updatedFields = append(updatedFields, "tags")
	}
	if len(req.Sources) > 0 {
		updatedFields = append(updatedFields, "sources")
	}
	if req.RawPrompt != nil {
		updatedFields = append(updatedFields, "raw_prompt")
	}
	if len(req.ViewsRaw) > 0 {
		updatedFields = append(updatedFields, "views_raw")
	}
	if len(req.FiltersRaw) > 0 {
		updatedFields = append(updatedFields, "filters_raw")
	}
	if req.DigestIntervalHours != nil {
		updatedFields = append(updatedFields, "digest_interval_hours")
	}

	_, err = h.feedRepo.Update(r.Context(), feedID, repository.UpdateFeedParams{
		Name:        req.Name,
		Description: req.Description,
		Tags:        req.Tags,
	})

	if req.RawPrompt != nil || len(req.ViewsRaw) > 0 || len(req.FiltersRaw) > 0 || req.DigestIntervalHours != nil {
		prompt, _ := h.promptRepo.GetByFeedID(r.Context(), feedID)
		if prompt != nil {
			h.promptRepo.Update(r.Context(), prompt.ID, repository.UpdatePromptParams{
				RawPrompt:           req.RawPrompt,
				ViewsRaw:            req.ViewsRaw,
				FiltersRaw:          req.FiltersRaw,
				DigestIntervalHours: req.DigestIntervalHours,
			})
		}
	}

	if len(req.Sources) > 0 {
		go h.syncFeedSources(r.Context(), feedID, req.Sources)
	}
	if err != nil {
		log.Error().Err(err).Msg("Failed to update feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, UpdateFeedResponse{
		Success:       true,
		FeedID:        feedID.String(),
		Message:       "Feed updated successfully",
		UpdatedFields: updatedFields,
	})
}

type RenameRequest struct {
	FeedID uuid.UUID `json:"feed_id"`
	Name   string    `json:"name"`
}

func (h *FeedHandler) RenameFeed(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req RenameRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, req.FeedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	if err := h.feedRepo.UpdateName(r.Context(), req.FeedID, req.Name); err != nil {
		log.Error().Err(err).Msg("Failed to rename feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Feed renamed successfully",
	})
}

type GenerateTitleRequest struct {
	Sources []clients.SourceInfo `json:"sources"`
}

type GenerateTitleResponse struct {
	Title string `json:"title"`
}

func (h *FeedHandler) GenerateTitle(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req GenerateTitleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Fetch sample posts from raw_feeds matching the source URLs
	samplePosts := h.fetchSamplePostsForSources(r.Context(), req.Sources)

	title, err := h.agents.GenerateFeedTitle(r.Context(), req.Sources, samplePosts)
	if err != nil {
		log.Error().Err(err).Msg("Failed to generate title")
		http.Error(w, "failed to generate title", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, GenerateTitleResponse{Title: title})
}

func (h *FeedHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := chi.URLParam(r, "feed_id")
	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	markedCount, err := h.postSeenRepo.MarkAllSeenInFeed(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to mark all read")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success":      true,
		"marked_count": markedCount,
	})
}

type SummarizeSourceInfo struct {
	PostID    string `json:"post_id"`
	SourceURL string `json:"source_url"`
}

type SummarizeUnseenPostResponse struct {
	ID           string                `json:"id"`
	CreatedAt    string                `json:"created_at"`
	FeedID       string                `json:"feed_id"`
	Title        *string               `json:"title,omitempty"`
	ImageURL     *string               `json:"image_url,omitempty"`
	MediaObjects json.RawMessage       `json:"media_objects,omitempty"`
	Views        map[string]string     `json:"views"`
	SourcesInfo  []SummarizeSourceInfo `json:"sources_info"`
}

func (h *FeedHandler) SummarizeUnseen(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	feedIDStr := chi.URLParam(r, "feed_id")
	feedID, err := uuid.Parse(feedIDStr)
	if err != nil {
		http.Error(w, "invalid feed_id", http.StatusBadRequest)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	feed, err := h.feedRepo.GetByID(r.Context(), feedID)
	if err != nil || feed == nil {
		http.Error(w, "feed not found", http.StatusNotFound)
		return
	}

	unseenPosts, err := h.postRepo.GetUnseenPosts(r.Context(), userID, feedID, 50)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get unseen posts")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if len(unseenPosts) == 0 {
		http.Error(w, "no unseen posts to summarize", http.StatusNotFound)
		return
	}

	postsData := make([]clients.PostSummary, 0, len(unseenPosts))
	sourcesInfo := make([]SummarizeSourceInfo, 0)
	postIDs := make([]uuid.UUID, 0, len(unseenPosts))

	for _, p := range unseenPosts {
		postIDs = append(postIDs, p.ID)

		title := ""
		if p.Title != nil {
			title = *p.Title
		}
		content := ""
		if text, ok := p.Views["full_text"]; ok {
			content = text
		} else if text, ok := p.Views["main_facts_context"]; ok {
			content = text
		}
		sourceURL := ""
		if len(p.Sources) > 0 {
			sourceURL = p.Sources[0].SourceURL
			sourcesInfo = append(sourcesInfo, SummarizeSourceInfo{
				PostID:    p.ID.String(),
				SourceURL: sourceURL,
			})
		}

		postsData = append(postsData, clients.PostSummary{
			ID:        p.ID.String(),
			Title:     title,
			Content:   content,
			SourceURL: sourceURL,
		})
	}

	desc := ""
	if feed.Description != nil {
		desc = *feed.Description
	}

	summary, err := h.agents.SummarizeUnseen(r.Context(), feedID.String(), postsData, clients.FeedConfigInfo{
		Name:        feed.Name,
		Description: desc,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to summarize unseen")
		http.Error(w, "failed to summarize", http.StatusInternalServerError)
		return
	}

	summaryTitle := "Summary of " + feed.Name
	newPost, err := h.postRepo.Create(r.Context(), repository.CreatePostParams{
		ID:     uuid.New(),
		FeedID: feedID,
		Title:  &summaryTitle,
		Views: map[string]string{
			"full_text": summary,
		},
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create summary post")
		http.Error(w, "failed to create summary post", http.StatusInternalServerError)
		return
	}

	for _, info := range sourcesInfo {
		if _, err := h.postRepo.CreateSource(r.Context(), newPost.ID, info.SourceURL); err != nil {
			log.Warn().Err(err).Str("source_url", info.SourceURL).Msg("Failed to create source")
		}
	}

	if err := h.postSeenRepo.MarkSeen(r.Context(), userID, postIDs); err != nil {
		log.Warn().Err(err).Msg("Failed to mark posts as seen")
	}

	writeJSON(w, http.StatusCreated, SummarizeUnseenPostResponse{
		ID:           newPost.ID.String(),
		CreatedAt:    newPost.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		FeedID:       newPost.FeedID.String(),
		Title:        newPost.Title,
		ImageURL:     newPost.ImageURL,
		MediaObjects: newPost.MediaObjects,
		Views:        newPost.Views,
		SourcesInfo:  sourcesInfo,
	})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

type SourceInput struct {
	URL  string `json:"url"`
	Type string `json:"type"`
}

type CreateFeedRequest struct {
	Name                string        `json:"name,omitempty"`
	Description         string        `json:"description,omitempty"`
	Tags                []string      `json:"tags,omitempty"`
	Sources             []SourceInput `json:"sources"`
	FeedType            string        `json:"feed_type"`
	RawPrompt           string        `json:"raw_prompt,omitempty"`
	ViewsRaw            []string      `json:"views_raw,omitempty"`
	FiltersRaw          []string      `json:"filters_raw,omitempty"`
	DigestIntervalHours *int          `json:"digest_interval_hours,omitempty"`
}

type CreateFeedResponse struct {
	Success            bool              `json:"success"`
	FeedID             string            `json:"feed_id"`
	PromptID           string            `json:"prompt_id"`
	Message            string            `json:"message"`
	IsCreatingFinished bool              `json:"is_creating_finished"`
	SourceTypes        map[string]string `json:"source_types,omitempty"`
}

func (h *FeedHandler) CreateFeed(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req CreateFeedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if len(req.Sources) == 0 {
		http.Error(w, "at least one source is required", http.StatusBadRequest)
		return
	}

	if req.FeedType == "" {
		req.FeedType = "SINGLE_POST"
	}

	if req.FeedType != "SINGLE_POST" && req.FeedType != "DIGEST" {
		http.Error(w, "feed_type must be SINGLE_POST or DIGEST", http.StatusBadRequest)
		return
	}

	log.Info().
		Str("user_id", userID.String()).
		Str("feed_type", req.FeedType).
		Int("sources_count", len(req.Sources)).
		Msg("Creating feed")

	currentFeeds, err := h.usersFeedRepo.CountUserFeeds(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to count user feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	var maxFeeds int
	sub, err := h.subscriptionRepo.GetCurrentSubscription(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get subscription")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if sub != nil {
		plan, err := h.subscriptionRepo.GetPlanByID(r.Context(), sub.SubscriptionPlanID)
		if err == nil && plan != nil {
			maxFeeds = plan.FeedsLimit
		}
	}

	if maxFeeds == 0 {
		freePlan, _ := h.subscriptionRepo.GetFreePlan(r.Context())
		if freePlan != nil {
			maxFeeds = freePlan.FeedsLimit
		} else {
			maxFeeds = 3
		}
	}

	if currentFeeds >= maxFeeds {
		writeJSON(w, http.StatusForbidden, CreateFeedResponse{
			Success: false,
			Message: "Feed limit exceeded",
		})
		return
	}

	sourceTypes := make(map[string]string)
	var invalidSources []string

	for _, source := range req.Sources {
		// Convert @username to full URL for validation (NATS service expects full URLs)
		validationURL := source.URL
		if strings.HasPrefix(source.URL, "@") {
			validationURL = "https://t.me/" + strings.TrimPrefix(source.URL, "@")
		}
		result, err := h.validation.ValidateSource(r.Context(), validationURL, source.Type, true)
		if err != nil {
			log.Warn().Err(err).Str("url", source.URL).Msg("Source validation failed")
			invalidSources = append(invalidSources, source.URL+": validation failed")
			continue
		}

		if !result.Valid {
			msg := "invalid source"
			if result.Error != nil {
				msg = *result.Error
			} else if result.Message != nil {
				msg = *result.Message
			}
			log.Warn().Str("url", source.URL).Str("error", msg).Msg("Source validation failed: invalid")
			invalidSources = append(invalidSources, source.URL+": "+msg)
			continue
		}

		if result.SourceType != nil {
			sourceTypes[source.URL] = *result.SourceType
		} else {
			sourceTypes[source.URL] = source.Type
		}
	}

	if len(invalidSources) > 0 {
		writeJSON(w, http.StatusUnprocessableEntity, CreateFeedResponse{
			Success: false,
			Message: "Invalid sources: " + invalidSources[0],
		})
		return
	}

	feedName := req.Name
	if feedName == "" {
		// Convert SourceInput to clients.SourceInfo for fetching sample posts
		sourceInfos := make([]clients.SourceInfo, len(req.Sources))
		for i, s := range req.Sources {
			sourceInfos[i] = clients.SourceInfo{URL: s.URL}
		}
		samplePosts := h.fetchSamplePostsForSources(r.Context(), sourceInfos)

		title, err := h.agents.GenerateFeedTitle(r.Context(), []clients.SourceInfo{
			{URL: req.Sources[0].URL, Description: req.RawPrompt},
		}, samplePosts)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to generate title, using default")
			feedName = "My Feed"
		} else {
			feedName = title
		}
	}

	sourceURLs := make([]string, len(req.Sources))
	for i, s := range req.Sources {
		sourceURLs[i] = s.URL
	}

	prePrompt, err := h.prePromptRepo.Create(r.Context(), repository.CreatePrePromptParams{
		Type:                req.FeedType,
		Prompt:              stringPtr(req.RawPrompt),
		Sources:             sourceURLs,
		ViewsRaw:            req.ViewsRaw,
		FiltersRaw:          req.FiltersRaw,
		DigestIntervalHours: req.DigestIntervalHours,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create pre_prompt")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	feedID := uuid.New()
	feed, err := h.feedRepo.Create(r.Context(), repository.CreateFeedParams{
		ID:          feedID,
		Name:        feedName,
		Type:        req.FeedType,
		Description: stringPtr(req.Description),
		Tags:        req.Tags,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	viewsConfig, _ := json.Marshal(req.ViewsRaw)
	filtersConfig, _ := json.Marshal(req.FiltersRaw)

	promptID := uuid.New()
	_, err = h.promptRepo.Create(r.Context(), repository.CreatePromptParams{
		ID:                  promptID,
		FeedID:              feed.ID,
		FeedType:            req.FeedType,
		ViewsConfig:         viewsConfig,
		FiltersConfig:       filtersConfig,
		PrePromptID:         &prePrompt.ID,
		DigestIntervalHours: req.DigestIntervalHours,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create prompt")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	for _, source := range req.Sources {
		sourceType := sourceTypes[source.URL]
		if sourceType == "" {
			sourceType = source.Type
		}

		rawFeed, err := h.rawFeedRepo.GetOrCreate(r.Context(), source.URL, sourceType, source.URL)
		if err != nil {
			log.Error().Err(err).Str("url", source.URL).Msg("Failed to create raw_feed")
			continue
		}

		if err := h.rawFeedRepo.LinkToPrompt(r.Context(), promptID, rawFeed.ID); err != nil {
			log.Error().Err(err).Msg("Failed to link raw_feed to prompt")
		}
	}

	if err := h.usersFeedRepo.Create(r.Context(), userID, feed.ID); err != nil {
		log.Error().Err(err).Msg("Failed to create users_feed")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if h.nc != nil {
		event := map[string]interface{}{
			"feed_id":   feed.ID.String(),
			"prompt_id": promptID.String(),
			"user_id":   userID.String(),
		}
		eventData, _ := json.Marshal(event)
		if err := h.nc.Publish("feed.initial_sync", eventData); err != nil {
			log.Warn().Err(err).Msg("Failed to publish feed.initial_sync event")
		}
	}

	hasTelegramSource := false
	for _, t := range sourceTypes {
		if strings.EqualFold(t, "TELEGRAM") {
			hasTelegramSource = true
			break
		}
	}

	if hasTelegramSource && h.telegram != nil {
		go func() {
			if err := h.telegram.TriggerSync(context.Background()); err != nil {
				log.Warn().Err(err).Msg("Failed to trigger Telegram sync")
			}
		}()
	}

	if h.adminNotify != nil && h.feedThreadID > 0 {
		userEmail := middleware.GetUserEmail(r.Context())
		// Resolve UUIDs to names for notification
		resolvedViews := req.ViewsRaw
		resolvedFilters := req.FiltersRaw
		if h.suggestionRepo != nil {
			resolvedViews = h.suggestionRepo.ResolveSuggestionNames(r.Context(), req.ViewsRaw)
			resolvedFilters = h.suggestionRepo.ResolveSuggestionNames(r.Context(), req.FiltersRaw)
		}
		go func() {
			h.adminNotify.NotifyNewFeed(context.Background(), h.feedThreadID, clients.NotifyFeedParams{
				Email:        userEmail,
				FeedID:       feed.ID.String(),
				FeedName:     feedName,
				FeedType:     req.FeedType,
				Sources:      sourceURLs,
				Filters:      resolvedFilters,
				Views:        resolvedViews,
				CurrentCount: currentFeeds,
				Limit:        maxFeeds,
			})
		}()
	}

	writeJSON(w, http.StatusCreated, CreateFeedResponse{
		Success:            true,
		FeedID:             feed.ID.String(),
		PromptID:           promptID.String(),
		Message:            "Feed '" + feedName + "' created successfully",
		IsCreatingFinished: false,
		SourceTypes:        sourceTypes,
	})
}

func stringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (h *FeedHandler) syncFeedSources(ctx context.Context, feedID uuid.UUID, sources []SourceInput) {
	prompt, err := h.promptRepo.GetByFeedID(ctx, feedID)
	if err != nil || prompt == nil {
		log.Warn().Err(err).Str("feed_id", feedID.String()).Msg("Failed to get prompt for source sync")
		return
	}

	for _, source := range sources {
		rawFeed, err := h.rawFeedRepo.GetOrCreate(ctx, source.URL, source.Type, source.URL)
		if err != nil {
			log.Warn().Err(err).Str("url", source.URL).Msg("Failed to get/create raw_feed")
			continue
		}

		if err := h.rawFeedRepo.LinkToPrompt(ctx, prompt.ID, rawFeed.ID); err != nil {
			log.Warn().Err(err).Msg("Failed to link raw_feed to prompt")
		}
	}
}

// fetchSamplePostsForSources finds raw_feeds by source URLs and returns sample post contents
func (h *FeedHandler) fetchSamplePostsForSources(ctx context.Context, sources []clients.SourceInfo) []string {
	if h.rawPostRepo == nil || h.rawFeedRepo == nil || len(sources) == 0 {
		return nil
	}

	// Extract URLs from sources
	urls := make([]string, len(sources))
	for i, s := range sources {
		urls[i] = s.URL
	}

	// Find raw_feed IDs by URLs
	rawFeedIDs, err := h.rawFeedRepo.FindIDsByURLs(ctx, urls)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to find raw_feeds by URLs")
		return nil
	}

	if len(rawFeedIDs) == 0 {
		return nil
	}

	// Fetch sample posts (up to 10)
	rawPosts, err := h.rawPostRepo.GetSamplePostsByRawFeedIDs(ctx, rawFeedIDs, 10)
	if err != nil {
		log.Warn().Err(err).Msg("Failed to fetch sample posts")
		return nil
	}

	// Extract post contents
	samplePosts := make([]string, 0, len(rawPosts))
	for _, p := range rawPosts {
		if p.Content != "" {
			samplePosts = append(samplePosts, p.Content)
		}
	}

	return samplePosts
}
