package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestUserHandler_Routes(t *testing.T) {
	handler := NewUserHandler(nil, nil, 0)
	router := handler.Routes()

	if router == nil {
		t.Fatal("Routes() returned nil")
	}
}

func TestUserHandler_AdminRoutes(t *testing.T) {
	handler := NewUserHandler(nil, nil, 0)
	router := handler.AdminRoutes()

	if router == nil {
		t.Fatal("AdminRoutes() returned nil")
	}
}

func TestUserHandler_DeleteMe_Unauthorized(t *testing.T) {
	handler := NewUserHandler(nil, nil, 0)

	req := newTestRequest(t, http.MethodDelete, "/users/me", nil)
	rr := httptest.NewRecorder()

	handler.DeleteMe(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestUserHandler_AdminDeleteUser_Unauthorized(t *testing.T) {
	handler := NewUserHandler(nil, nil, 0)

	req := newTestRequest(t, http.MethodDelete, "/admin/users/"+uuid.New().String(), nil)
	req = withURLParam(req, "target_user_id", uuid.New().String())
	rr := httptest.NewRecorder()

	handler.AdminDeleteUser(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

func TestUserHandler_Heartbeat_Unauthorized(t *testing.T) {
	handler := NewUserHandler(nil, nil, 0)

	req := newTestRequest(t, http.MethodPost, "/users/heartbeat", nil)
	rr := httptest.NewRecorder()

	handler.Heartbeat(rr, req)

	assertStatusCode(t, rr.Code, http.StatusUnauthorized)
}

