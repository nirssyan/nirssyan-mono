package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type PostHandler struct {
	feedRepo     *repository.FeedRepository
	postRepo     *repository.PostRepository
	postSeenRepo *repository.PostSeenRepository
}

func NewPostHandler(
	feedRepo *repository.FeedRepository,
	postRepo *repository.PostRepository,
	postSeenRepo *repository.PostSeenRepository,
) *PostHandler {
	return &PostHandler{
		feedRepo:     feedRepo,
		postRepo:     postRepo,
		postSeenRepo: postSeenRepo,
	}
}

func (h *PostHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Post("/seen", h.MarkSeen)
	r.Get("/{post_id}", h.GetPost)
	r.Get("/feed/{feed_id}", h.GetFeedPosts)

	return r
}

type MarkSeenRequest struct {
	PostIDs []uuid.UUID `json:"post_ids"`
}

func (h *PostHandler) MarkSeen(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req MarkSeenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := h.postSeenRepo.MarkSeen(r.Context(), userID, req.PostIDs); err != nil {
		log.Error().Err(err).Msg("Failed to mark posts seen")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success":      true,
		"marked_count": len(req.PostIDs),
	})
}

type PostResponse struct {
	ID                        uuid.UUID               `json:"id"`
	CreatedAt                 string                  `json:"created_at"`
	FeedID                    uuid.UUID               `json:"feed_id"`
	Title                     *string                 `json:"title,omitempty"`
	ImageURL                  *string                 `json:"image_url,omitempty"`
	MediaObjects              json.RawMessage         `json:"media_objects,omitempty"`
	Views                     map[string]string       `json:"views"`
	ModerationAction          *string                 `json:"moderation_action,omitempty"`
	ModerationLabels          []string                `json:"moderation_labels"`
	ModerationMatchedEntities []string                `json:"moderation_matched_entities"`
	Sources                   []repository.PostSource `json:"sources"`
	Seen                      bool                    `json:"seen"`
}

func (h *PostHandler) GetPost(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	postIDStr := chi.URLParam(r, "post_id")
	postID, err := uuid.Parse(postIDStr)
	if err != nil {
		http.Error(w, "invalid post_id", http.StatusBadRequest)
		return
	}

	post, err := h.postRepo.GetByID(r.Context(), postID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get post")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if post == nil {
		http.Error(w, "post not found", http.StatusNotFound)
		return
	}

	hasAccess, err := h.feedRepo.UserHasAccess(r.Context(), userID, post.FeedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to check access")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if !hasAccess {
		http.Error(w, "post not found", http.StatusNotFound)
		return
	}

	isSeen, _ := h.postSeenRepo.IsPostSeen(r.Context(), userID, postID)

	title := post.Title
	if containsLabel(post.ModerationLabels, "foreign_agent") && title != nil {
		markedTitle := *title + " *"
		title = &markedTitle
	}

	views := post.Views
	if len(post.ModerationMatchedEntities) > 0 {
		views = applyEntityMarkers(views, post.ModerationMatchedEntities)
	}

	writeJSON(w, http.StatusOK, PostResponse{
		ID:                        post.ID,
		CreatedAt:                 post.CreatedAt.Format("2006-01-02T15:04:05Z"),
		FeedID:                    post.FeedID,
		Title:                     title,
		ImageURL:                  post.ImageURL,
		MediaObjects:              post.MediaObjects,
		Views:                     views,
		ModerationAction:          post.ModerationAction,
		ModerationLabels:          emptyIfNil(post.ModerationLabels),
		ModerationMatchedEntities: emptyIfNil(post.ModerationMatchedEntities),
		Sources:                   post.Sources,
		Seen:                      isSeen,
	})
}

func emptyIfNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

func containsLabel(labels []string, label string) bool {
	for _, l := range labels {
		if l == label {
			return true
		}
	}
	return false
}

func applyEntityMarkers(views map[string]string, entities []string) map[string]string {
	if len(views) == 0 || len(entities) == 0 {
		return views
	}
	result := make(map[string]string, len(views))
	for k, v := range views {
		for _, entity := range entities {
			if entity != "" {
				v = replaceIgnoreCase(v, entity, entity+" *")
			}
		}
		result[k] = v
	}
	return result
}

func replaceIgnoreCase(s, old, new string) string {
	if old == "" {
		return s
	}
	lowerS := strings.ToLower(s)
	lowerOld := strings.ToLower(old)

	var result strings.Builder
	i := 0
	for i < len(s) {
		idx := strings.Index(lowerS[i:], lowerOld)
		if idx == -1 {
			result.WriteString(s[i:])
			break
		}
		result.WriteString(s[i : i+idx])
		result.WriteString(new)
		i += idx + len(old)
	}
	return result.String()
}

func (h *PostHandler) GetPostPublic(w http.ResponseWriter, r *http.Request) {
	postIDStr := chi.URLParam(r, "post_id")
	postID, err := uuid.Parse(postIDStr)
	if err != nil {
		http.Error(w, "invalid post_id", http.StatusBadRequest)
		return
	}

	post, err := h.postRepo.GetByID(r.Context(), postID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get post")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	if post == nil {
		http.Error(w, "post not found", http.StatusNotFound)
		return
	}

	if post.ModerationAction != nil && *post.ModerationAction == "block" {
		http.Error(w, "post not found", http.StatusNotFound)
		return
	}

	title := post.Title
	if containsLabel(post.ModerationLabels, "foreign_agent") && title != nil {
		markedTitle := *title + " *"
		title = &markedTitle
	}

	views := post.Views
	if len(post.ModerationMatchedEntities) > 0 {
		views = applyEntityMarkers(views, post.ModerationMatchedEntities)
	}

	writeJSON(w, http.StatusOK, PostResponse{
		ID:           post.ID,
		CreatedAt:    post.CreatedAt.Format("2006-01-02T15:04:05Z"),
		FeedID:       post.FeedID,
		Title:        title,
		ImageURL:     post.ImageURL,
		MediaObjects: post.MediaObjects,
		Views:        views,
		Sources:      post.Sources,
		Seen:         false,
	})
}

type GetFeedPostsResponse struct {
	Posts      []PostResponse `json:"posts"`
	NextCursor *string        `json:"next_cursor,omitempty"`
	HasMore    bool           `json:"has_more"`
	TotalCount int            `json:"total_count"`
}

func (h *PostHandler) GetFeedPosts(w http.ResponseWriter, r *http.Request) {
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

	limit := 20
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	var cursor *string
	if c := r.URL.Query().Get("cursor"); c != "" {
		cursor = &c
	}

	totalCount, err := h.postRepo.CountByFeedID(r.Context(), feedID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to count posts")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	posts, err := h.postRepo.GetFeedPostsWithCursor(r.Context(), feedID, limit+1, cursor)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get feed posts")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	hasMore := len(posts) > limit
	if hasMore {
		posts = posts[:limit]
	}

	var nextCursor *string
	if hasMore && len(posts) > 0 {
		lastPost := posts[len(posts)-1]
		encoded := repository.EncodeCursor(lastPost.CreatedAt, lastPost.ID)
		nextCursor = &encoded
	}

	postIDs := make([]uuid.UUID, 0, len(posts))
	for _, p := range posts {
		postIDs = append(postIDs, p.ID)
	}
	seenMap, _ := h.postSeenRepo.GetSeenMap(r.Context(), userID, postIDs)

	response := make([]PostResponse, 0, len(posts))
	for _, p := range posts {
		if p.ModerationAction != nil && *p.ModerationAction == "block" {
			continue
		}

		title := p.Title
		if containsLabel(p.ModerationLabels, "foreign_agent") && title != nil {
			markedTitle := *title + " *"
			title = &markedTitle
		}

		views := p.Views
		if len(p.ModerationMatchedEntities) > 0 {
			views = applyEntityMarkers(views, p.ModerationMatchedEntities)
		}

		isSeen := seenMap[p.ID]

		response = append(response, PostResponse{
			ID:                        p.ID,
			CreatedAt:                 p.CreatedAt.Format("2006-01-02T15:04:05Z"),
			FeedID:                    p.FeedID,
			Title:                     title,
			ImageURL:                  p.ImageURL,
			MediaObjects:              p.MediaObjects,
			Views:                     views,
			ModerationAction:          p.ModerationAction,
			ModerationLabels:          emptyIfNil(p.ModerationLabels),
			ModerationMatchedEntities: emptyIfNil(p.ModerationMatchedEntities),
			Sources:                   p.Sources,
			Seen:                      isSeen,
		})
	}

	writeJSON(w, http.StatusOK, GetFeedPostsResponse{
		Posts:      response,
		NextCursor: nextCursor,
		HasMore:    hasMore,
		TotalCount: totalCount,
	})
}
