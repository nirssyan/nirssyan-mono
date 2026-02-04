package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestUsersFeedHandler_Routes(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestUsersFeedHandler_Subscribe_Unauthorized(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)

	req := newTestRequest(t, http.MethodPost, "/users_feeds", map[string]string{
		"feed_id": uuid.New().String(),
	})
	rr := httptest.NewRecorder()

	handler.Subscribe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestUsersFeedHandler_Subscribe_InvalidBody(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/users_feeds", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.Subscribe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestUsersFeedHandler_Unsubscribe_Unauthorized(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)

	req := newTestRequest(t, http.MethodDelete, "/users_feeds?feed_id="+uuid.New().String(), nil)
	rr := httptest.NewRecorder()

	handler.Unsubscribe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestUsersFeedHandler_Unsubscribe_MissingFeedID(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodDelete, "/users_feeds", nil, userID)
	rr := httptest.NewRecorder()

	handler.Unsubscribe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestUsersFeedHandler_Unsubscribe_InvalidFeedID(t *testing.T) {
	handler := NewUsersFeedHandler(nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodDelete, "/users_feeds?feed_id=invalid", nil, userID)
	rr := httptest.NewRecorder()

	handler.Unsubscribe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}
