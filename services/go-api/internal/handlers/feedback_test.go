package handlers

import (
	"bytes"
	"context"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
)

func newFeedbackHandler() *FeedbackHandler {
	return NewFeedbackHandler(nil, nil, nil, nil, "", "", 0, "", "")
}

func TestFeedbackHandler_Routes(t *testing.T) {
	handler := newFeedbackHandler()
	router := handler.Routes()
	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestFeedbackHandler_SubmitFeedback_Unauthorized(t *testing.T) {
	handler := newFeedbackHandler()

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	w.WriteField("message", "test")
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/feedback", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	rr := httptest.NewRecorder()

	handler.SubmitFeedback(rr, req)
	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestFeedbackHandler_SubmitFeedback_EmptyForm(t *testing.T) {
	handler := newFeedbackHandler()
	userID := uuid.New()

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/feedback", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.SubmitFeedback(rr, req)
	assertStatusCode(t, rr.Code, http.StatusBadRequest)

	if !strings.Contains(rr.Body.String(), "message or images required") {
		t.Errorf("expected 'message or images required' error, got: %s", rr.Body.String())
	}
}

func TestFeedbackHandler_SubmitFeedback_TooManyImages(t *testing.T) {
	handler := newFeedbackHandler()
	userID := uuid.New()

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	for i := 0; i < 6; i++ {
		part, _ := w.CreateFormFile("images", "test.jpg")
		part.Write([]byte("fake-image-data"))
	}
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/feedback", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.SubmitFeedback(rr, req)
	assertStatusCode(t, rr.Code, http.StatusBadRequest)

	if !strings.Contains(rr.Body.String(), "too many images") {
		t.Errorf("expected 'too many images' error, got: %s", rr.Body.String())
	}
}

func TestFeedbackHandler_SubmitFeedback_InvalidMIME(t *testing.T) {
	handler := newFeedbackHandler()
	userID := uuid.New()

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	part, _ := w.CreateFormFile("images", "test.gif")
	part.Write([]byte("fake-image-data"))
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/feedback", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.SubmitFeedback(rr, req)
	assertStatusCode(t, rr.Code, http.StatusBadRequest)

	if !strings.Contains(rr.Body.String(), "invalid image type") {
		t.Errorf("expected 'invalid image type' error, got: %s", rr.Body.String())
	}
}

func TestFeedbackHandler_SubmitFeedback_ImageTooLarge(t *testing.T) {
	handler := newFeedbackHandler()
	userID := uuid.New()

	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	part, _ := w.CreateFormFile("images", "large.jpg")
	largeData := make([]byte, 11<<20) // 11MB
	part.Write(largeData)
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/feedback", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.SubmitFeedback(rr, req)
	assertStatusCode(t, rr.Code, http.StatusBadRequest)

	if !strings.Contains(rr.Body.String(), "exceeds max size") {
		t.Errorf("expected 'exceeds max size' error, got: %s", rr.Body.String())
	}
}
