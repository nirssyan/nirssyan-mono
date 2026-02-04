package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestTagsHandler_Routes(t *testing.T) {
	handler := NewTagsHandler(nil, nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestTagsHandler_AuthenticatedRoutes(t *testing.T) {
	handler := NewTagsHandler(nil, nil)
	router := handler.AuthenticatedRoutes()

	if router == nil {
		t.Fatal("AuthenticatedRoutes() returned nil")
	}
}

func TestTagsHandler_GetUserTags_Unauthorized(t *testing.T) {
	handler := NewTagsHandler(nil, nil)

	req := newTestRequest(t, http.MethodGet, "/users/tags", nil)
	rr := httptest.NewRecorder()

	handler.GetUserTags(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTagsHandler_UpdateUserTags_Unauthorized(t *testing.T) {
	handler := NewTagsHandler(nil, nil)

	req := newTestRequest(t, http.MethodPut, "/users/tags", map[string]interface{}{
		"tag_ids": []string{uuid.New().String()},
	})
	rr := httptest.NewRecorder()

	handler.UpdateUserTags(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTagsHandler_UpdateUserTags_InvalidBody(t *testing.T) {
	handler := NewTagsHandler(nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPut, "/users/tags", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.UpdateUserTags(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestTagsHandler_UpdateUserTags_TooManyTags(t *testing.T) {
	handler := NewTagsHandler(nil, nil)
	userID := uuid.New()

	tagIDs := make([]string, 11)
	for i := 0; i < 11; i++ {
		tagIDs[i] = uuid.New().String()
	}

	req := newAuthenticatedRequest(t, http.MethodPut, "/users/tags", map[string]interface{}{
		"tag_ids": tagIDs,
	}, userID)
	rr := httptest.NewRecorder()

	handler.UpdateUserTags(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestTagsHandler_UpdateUserTags_InvalidTagID(t *testing.T) {
	handler := NewTagsHandler(nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPut, "/users/tags", map[string]interface{}{
		"tag_ids": []string{"not-a-uuid"},
	}, userID)
	rr := httptest.NewRecorder()

	handler.UpdateUserTags(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestTagResponse_Fields(t *testing.T) {
	resp := TagResponse{
		ID:   "test-id",
		Name: "Test Tag",
		Slug: "test-tag",
	}

	if resp.ID != "test-id" {
		t.Errorf("ID = %q, want test-id", resp.ID)
	}
	if resp.Name != "Test Tag" {
		t.Errorf("Name = %q, want Test Tag", resp.Name)
	}
	if resp.Slug != "test-tag" {
		t.Errorf("Slug = %q, want test-tag", resp.Slug)
	}
}
