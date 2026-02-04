package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestTelegramLinkHandler_Routes(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestTelegramLinkHandler_AuthenticatedRoutes(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)
	router := handler.AuthenticatedRoutes()

	if router == nil {
		t.Fatal("AuthenticatedRoutes() returned nil")
	}
}

func TestTelegramLinkHandler_GetLinkURL_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodGet, "/telegram/auth/link-url", nil)
	rr := httptest.NewRecorder()

	handler.GetLinkURL(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramLinkHandler_GetStatus_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodGet, "/telegram/auth/status", nil)
	rr := httptest.NewRecorder()

	handler.GetStatus(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramLinkHandler_Unlink_Unauthorized(t *testing.T) {
	handler := NewTelegramLinkHandler(nil, nil, "testbot", 10)

	req := newTestRequest(t, http.MethodDelete, "/telegram/auth/unlink", nil)
	rr := httptest.NewRecorder()

	handler.Unlink(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestTelegramStatusResponse_EmptyAccount(t *testing.T) {
	resp := TelegramStatusResponse{
		IsLinked: false,
		Account:  nil,
	}

	if resp.IsLinked {
		t.Error("expected IsLinked=false")
	}
	if resp.Account != nil {
		t.Error("expected Account=nil")
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

func TestTelegramAccountInfo_Fields(t *testing.T) {
	username := "testuser"
	firstName := "Test"

	info := TelegramAccountInfo{
		TelegramID:        12345,
		TelegramUsername:  &username,
		TelegramFirstName: &firstName,
		LinkedAt:          "2024-01-01T00:00:00Z",
	}

	if info.TelegramID != 12345 {
		t.Errorf("TelegramID = %d, want 12345", info.TelegramID)
	}
	if *info.TelegramUsername != "testuser" {
		t.Errorf("TelegramUsername = %s, want testuser", *info.TelegramUsername)
	}
	if *info.TelegramFirstName != "Test" {
		t.Errorf("TelegramFirstName = %s, want Test", *info.TelegramFirstName)
	}
}

func TestTelegramStatusResponse_WithAccount(t *testing.T) {
	userID := uuid.New()
	username := "testuser"

	resp := TelegramStatusResponse{
		IsLinked: true,
		Account: &TelegramAccountInfo{
			TelegramID:       12345,
			TelegramUsername: &username,
			LinkedAt:         "2024-01-01T00:00:00Z",
		},
	}

	if !resp.IsLinked {
		t.Error("expected IsLinked=true")
	}
	if resp.Account == nil {
		t.Fatal("expected Account to not be nil")
	}
	if resp.Account.TelegramID != 12345 {
		t.Errorf("TelegramID = %d, want 12345", resp.Account.TelegramID)
	}

	_ = userID
}
