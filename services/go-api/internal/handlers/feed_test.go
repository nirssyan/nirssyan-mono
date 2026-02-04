package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestFeedHandler_Routes(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestFeedHandler_GetUserFeeds_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodGet, "/feeds", nil)
	rr := httptest.NewRecorder()

	handler.GetUserFeeds(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_UpdateFeed_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPatch, "/feeds/"+uuid.New().String(), map[string]string{
		"name": "New Name",
	})
	req = withURLParam(req, "feed_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.UpdateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_UpdateFeed_InvalidFeedID(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPatch, "/feeds/invalid", map[string]string{
		"name": "New Name",
	}, userID)
	req = withURLParam(req, "feed_id", "invalid")
	rr := httptest.NewRecorder()

	handler.UpdateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_UpdateFeed_InvalidBody(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()
	feedID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPatch, "/feeds/"+feedID.String(), "invalid", userID)
	req = withURLParam(req, "feed_id", feedID.String())
	rr := httptest.NewRecorder()

	handler.UpdateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_RenameFeed_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPost, "/feeds/rename", map[string]interface{}{
		"feed_id": uuid.New().String(),
		"name":    "New Name",
	})
	rr := httptest.NewRecorder()

	handler.RenameFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_RenameFeed_InvalidBody(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/rename", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.RenameFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_GenerateTitle_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPost, "/feeds/generate_title", map[string]interface{}{
		"sources": []interface{}{},
	})
	rr := httptest.NewRecorder()

	handler.GenerateTitle(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_GenerateTitle_InvalidBody(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/generate_title", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.GenerateTitle(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_MarkAllRead_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPost, "/feeds/read_all/"+uuid.New().String(), nil)
	req = withURLParam(req, "feed_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.MarkAllRead(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_MarkAllRead_InvalidFeedID(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/read_all/invalid", nil, userID)
	req = withURLParam(req, "feed_id", "invalid")
	rr := httptest.NewRecorder()

	handler.MarkAllRead(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_SummarizeUnseen_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPost, "/feeds/summarize_unseen/"+uuid.New().String(), nil)
	req = withURLParam(req, "feed_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.SummarizeUnseen(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_SummarizeUnseen_InvalidFeedID(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/summarize_unseen/invalid", nil, userID)
	req = withURLParam(req, "feed_id", "invalid")
	rr := httptest.NewRecorder()

	handler.SummarizeUnseen(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_CreateFeed_Unauthorized(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)

	req := newTestRequest(t, http.MethodPost, "/feeds/create", map[string]interface{}{
		"sources":   []interface{}{map[string]string{"url": "https://test.com", "type": "rss"}},
		"feed_type": "SINGLE_POST",
	})
	rr := httptest.NewRecorder()

	handler.CreateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedHandler_CreateFeed_InvalidBody(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/create", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.CreateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_CreateFeed_NoSources(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/create", map[string]interface{}{
		"sources":   []interface{}{},
		"feed_type": "SINGLE_POST",
	}, userID)
	rr := httptest.NewRecorder()

	handler.CreateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedHandler_CreateFeed_InvalidFeedType(t *testing.T) {
	handler := NewFeedHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feeds/create", map[string]interface{}{
		"sources":   []interface{}{map[string]string{"url": "https://test.com", "type": "rss"}},
		"feed_type": "INVALID",
	}, userID)
	rr := httptest.NewRecorder()

	handler.CreateFeed(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestStringPtr(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantNil bool
	}{
		{
			name:    "empty string returns nil",
			input:   "",
			wantNil: true,
		},
		{
			name:    "non-empty string returns pointer",
			input:   "hello",
			wantNil: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := stringPtr(tt.input)
			if tt.wantNil && got != nil {
				t.Errorf("stringPtr() = %v, want nil", got)
			}
			if !tt.wantNil && (got == nil || *got != tt.input) {
				t.Errorf("stringPtr() = %v, want %v", got, tt.input)
			}
		})
	}
}
