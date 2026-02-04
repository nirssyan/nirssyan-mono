package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
)

func newTestRequest(t *testing.T, method, path string, body interface{}) *http.Request {
	t.Helper()
	var bodyStr string
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("failed to marshal body: %v", err)
		}
		bodyStr = string(b)
	}
	req := httptest.NewRequest(method, path, strings.NewReader(bodyStr))
	req.Header.Set("Content-Type", "application/json")
	return req
}

func newAuthenticatedRequest(t *testing.T, method, path string, body interface{}, userID uuid.UUID) *http.Request {
	t.Helper()
	req := newTestRequest(t, method, path, body)
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	return req.WithContext(ctx)
}

func withURLParam(req *http.Request, key, value string) *http.Request {
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add(key, value)
	return req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
}

func assertStatusCode(t *testing.T, got, want int) {
	t.Helper()
	if got != want {
		t.Errorf("status code = %d, want %d", got, want)
	}
}

func assertJSONResponse(t *testing.T, rr *httptest.ResponseRecorder, v interface{}) {
	t.Helper()
	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("content-type = %q, want application/json", ct)
	}
	if err := json.Unmarshal(rr.Body.Bytes(), v); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}
}
