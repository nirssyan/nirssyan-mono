package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler_Healthz(t *testing.T) {
	handler := NewHealthHandler(nil)

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()

	handler.Healthz(rr, req)

	assertStatusCode(t, rr.Code, http.StatusOK)

	var resp map[string]string
	assertJSONResponse(t, rr, &resp)

	if resp["status"] != "ok" {
		t.Errorf("status = %q, want ok", resp["status"])
	}
}

func TestHealthHandler_Readyz_NoPool(t *testing.T) {
	handler := NewHealthHandler(nil)

	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rr := httptest.NewRecorder()

	handler.Readyz(rr, req)

	assertStatusCode(t, rr.Code, http.StatusServiceUnavailable)

	body := rr.Body.String()
	if body != "Database not ready" {
		t.Errorf("body = %q, want 'Database not ready'", body)
	}
}
