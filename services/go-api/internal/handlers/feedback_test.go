package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestFeedbackHandler_Routes(t *testing.T) {
	handler := NewFeedbackHandler(nil, "", "")
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestFeedbackHandler_SubmitFeedback_Unauthorized(t *testing.T) {
	handler := NewFeedbackHandler(nil, "", "")

	req := newTestRequest(t, http.MethodPost, "/feedback", map[string]string{
		"message": "Test feedback",
		"type":    "bug",
	})
	rr := httptest.NewRecorder()

	handler.SubmitFeedback(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedbackHandler_SubmitFeedback_InvalidBody(t *testing.T) {
	handler := NewFeedbackHandler(nil, "", "")
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feedback", "invalid", userID)
	rr := httptest.NewRecorder()

	handler.SubmitFeedback(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}

func TestFeedbackHandler_SubmitFeedback_MissingMessage(t *testing.T) {
	handler := NewFeedbackHandler(nil, "", "")
	userID := uuid.New()

	req := newAuthenticatedRequest(t, http.MethodPost, "/feedback", map[string]string{
		"message": "",
		"type":    "bug",
	}, userID)
	rr := httptest.NewRecorder()

	handler.SubmitFeedback(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}
