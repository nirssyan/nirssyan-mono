package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestDeviceTokenHandler_Routes(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestDeviceTokenHandler_RegisterToken_Unauthorized(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)

	req := newTestRequest(t, http.MethodPost, "/device-tokens", map[string]string{
		"token":    "test-token",
		"platform": "ios",
	})
	rr := httptest.NewRecorder()

	handler.RegisterToken(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestDeviceTokenHandler_RegisterToken_InvalidBody(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/device-tokens", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.RegisterToken(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestDeviceTokenHandler_RegisterToken_MissingFields(t *testing.T) {
	tests := []struct {
		name string
		body map[string]string
	}{
		{
			name: "missing token",
			body: map[string]string{"platform": "ios"},
		},
		{
			name: "missing platform",
			body: map[string]string{"token": "test-token"},
		},
		{
			name: "empty token",
			body: map[string]string{"token": "", "platform": "ios"},
		},
		{
			name: "empty platform",
			body: map[string]string{"token": "test-token", "platform": ""},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := NewDeviceTokenHandler(nil)
			userID := uuid.New()

			req := newAuthenticatedRequest(t, http.MethodPost, "/device-tokens", tt.body, userID)
			rr := httptest.NewRecorder()

			handler.RegisterToken(rr, req)

			assertStatusCode(t, rr.Code, http.StatusBadRequest)
		})
	}
}

func TestDeviceTokenHandler_UnregisterToken_Unauthorized(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)

	req := newTestRequest(t, http.MethodDelete, "/device-tokens", map[string]string{
		"token": "test-token",
	})
	rr := httptest.NewRecorder()

	handler.UnregisterToken(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestDeviceTokenHandler_UnregisterToken_InvalidBody(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodDelete, "/device-tokens", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.UnregisterToken(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestDeviceTokenHandler_UnregisterToken_MissingToken(t *testing.T) {
	handler := NewDeviceTokenHandler(nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodDelete, "/device-tokens", map[string]string{
		"token": "",
	}, userID)
	rr := httptest.NewRecorder()

	handler.UnregisterToken(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}
