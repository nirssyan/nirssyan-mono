package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTelegramLinkHandler_AuthenticatedRoutes(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)
	router := handler.AuthenticatedRoutes()

	if router == nil {
		t.Fatal("AuthenticatedRoutes() returned nil")
	}
}

func TestTelegramLinkHandler_GetLinkURL_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodGet, "/telegram/link-url", nil)
	rr := httptest.NewRecorder()

	handler.GetLinkURL(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramLinkHandler_GetStatus_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodGet, "/telegram/status", nil)
	rr := httptest.NewRecorder()

	handler.GetStatus(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramLinkHandler_Unlink_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodDelete, "/telegram/unlink", nil)
	rr := httptest.NewRecorder()

	handler.Unlink(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramStatusResponse_NotLinked(t *testing.T) {
	resp := TelegramStatusResponse{
		Linked: false,
	}

	if resp.Linked {
		t.Error("expected Linked=false")
	}
	if resp.TelegramUsername != nil {
		t.Error("expected TelegramUsername=nil")
	}
}

func TestTelegramUnlinkResponse_Fields(t *testing.T) {
	resp := TelegramUnlinkResponse{
		Success: true,
		Message: "test message",
	}

	if !resp.Success {
		t.Error("expected Success=true")
	}
	if resp.Message != "test message" {
		t.Errorf("unexpected Message: %s", resp.Message)
	}
}

func TestNewTelegramLinkHandler(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 15)

	if handler == nil {
		t.Fatal("NewTelegramLinkHandler returned nil")
	}
	if handler.botUsername != "testbot" {
		t.Errorf("botUsername = %q, want testbot", handler.botUsername)
	}
	if handler.linkExpiryMins != 15 {
		t.Errorf("linkExpiryMins = %d, want 15", handler.linkExpiryMins)
	}
}

func TestLinkURLResponse_Fields(t *testing.T) {
	resp := LinkURLResponse{
		URL: "https://t.me/testbot?start=abc123",
	}

	if resp.URL != "https://t.me/testbot?start=abc123" {
		t.Errorf("unexpected URL: %s", resp.URL)
	}
}

func TestTelegramStatusResponse_WithUsername(t *testing.T) {
	username := "testuser"

	resp := TelegramStatusResponse{
		Linked:           true,
		TelegramUsername: &username,
	}

	if !resp.Linked {
		t.Error("expected Linked=true")
	}
	if resp.TelegramUsername == nil {
		t.Fatal("expected TelegramUsername to not be nil")
	}
	if *resp.TelegramUsername != "testuser" {
		t.Errorf("TelegramUsername = %s, want testuser", *resp.TelegramUsername)
	}
}
