package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestSubscriptionHandler_Routes(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestSubscriptionHandler_GetCurrentSubscription_Unauthorized(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodGet, "/subscriptions/current", nil)
	rr := httptest.NewRecorder()

	handler.GetCurrentSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestSubscriptionHandler_GetLimits_Unauthorized(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodGet, "/subscriptions/limits", nil)
	rr := httptest.NewRecorder()

	handler.GetLimits(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestSubscriptionHandler_CreateManualSubscription_InvalidBody(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodPost, "/subscriptions/manual", "invalid")
	rr := httptest.NewRecorder()

	handler.CreateManualSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestSubscriptionHandler_CreateManualSubscription_MissingUserID(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodPost, "/subscriptions/manual", map[string]interface{}{
		"user_id":   uuid.Nil,
		"months":    1,
		"plan_type": "PRO",
	})
	rr := httptest.NewRecorder()

	handler.CreateManualSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestSubscriptionHandler_ValidateSubscription_Unauthorized(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)

	req := newTestRequest(t, http.MethodPost, "/subscriptions/validate", map[string]string{
		"package_name":    "com.test.app",
		"subscription_id": "sub_123",
		"purchase_token":  "token_abc",
	})
	rr := httptest.NewRecorder()

	handler.ValidateSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestSubscriptionHandler_ValidateSubscription_InvalidBody(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/subscriptions/validate", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.ValidateSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestSubscriptionHandler_ValidateSubscription_MissingFields(t *testing.T) {
	tests := []struct {
		name string
		body map[string]string
	}{
		{
			name: "missing package_name",
			body: map[string]string{"subscription_id": "sub", "purchase_token": "tok"},
		},
		{
			name: "missing subscription_id",
			body: map[string]string{"package_name": "pkg", "purchase_token": "tok"},
		},
		{
			name: "missing purchase_token",
			body: map[string]string{"package_name": "pkg", "subscription_id": "sub"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := NewSubscriptionHandler(nil, nil, nil)
			userID := uuid.New()

			req := newAuthenticatedRequest(t, http.MethodPost, "/subscriptions/validate", tt.body, userID)
			rr := httptest.NewRecorder()

			handler.ValidateSubscription(rr, req)

			assertStatusCode(t, rr.Code, http.StatusBadRequest)
		})
	}
}

func TestSubscriptionHandler_ValidateSubscription_NoRuStoreClient(t *testing.T) {
	handler := NewSubscriptionHandler(nil, nil, nil)
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/subscriptions/validate", map[string]string{
		"package_name":    "com.test.app",
		"subscription_id": "sub_123",
		"purchase_token":  "token_abc",
	}, userID)
	rr := httptest.NewRecorder()

	handler.ValidateSubscription(rr, req)

	assertStatusCode(t, rr.Code, http.StatusServiceUnavailable)

	var resp ValidateSubscriptionResponse
	assertJSONResponse(t, rr, &resp)
	if resp.Success {
		t.Error("expected success=false")
	}
	if resp.Message != "RuStore integration not configured" {
		t.Errorf("unexpected message: %s", resp.Message)
	}
}
