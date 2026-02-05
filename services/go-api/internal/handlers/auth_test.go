package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/golang-jwt/jwt/v5"

	"github.com/MargoRSq/infatium-mono/services/go-api/internal/config"
)

const testJWTSecret = "test-secret-key-for-demo-login"

func newDemoConfig() *config.Config {
	return &config.Config{
		DemoModeEnabled:   true,
		DemoAccountEmail:  "demo@infatium.ru",
		DemoAccountUserID: "5b684a49-6f14-484c-ba99-fd6fc8a54f90",
		JWTSecret:         testJWTSecret,
	}
}

func TestAuthHandler_DemoLogin_Success(t *testing.T) {
	cfg := newDemoConfig()
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "demo@infatium.ru",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusOK)

	var resp authResponse
	assertJSONResponse(t, rr, &resp)

	if resp.AccessToken == "" {
		t.Error("access_token is empty")
	}
	if resp.RefreshToken == "" {
		t.Error("refresh_token is empty")
	}
	if resp.TokenType != "bearer" {
		t.Errorf("token_type = %q, want bearer", resp.TokenType)
	}
	if resp.ExpiresIn != 3600 {
		t.Errorf("expires_in = %d, want 3600", resp.ExpiresIn)
	}
	if resp.User == nil {
		t.Fatal("user is nil")
	}
	if resp.User.ID != cfg.DemoAccountUserID {
		t.Errorf("user.id = %q, want %q", resp.User.ID, cfg.DemoAccountUserID)
	}
	if resp.User.Email != cfg.DemoAccountEmail {
		t.Errorf("user.email = %q, want %q", resp.User.Email, cfg.DemoAccountEmail)
	}
}

func TestAuthHandler_DemoLogin_CaseInsensitiveEmail(t *testing.T) {
	cfg := newDemoConfig()
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "Demo@Infatium.RU",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusOK)
}

func TestAuthHandler_DemoLogin_JWTClaims(t *testing.T) {
	cfg := newDemoConfig()
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "demo@infatium.ru",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusOK)

	var resp authResponse
	assertJSONResponse(t, rr, &resp)

	token, err := jwt.Parse(resp.AccessToken, func(token *jwt.Token) (interface{}, error) {
		return []byte(testJWTSecret), nil
	})
	if err != nil {
		t.Fatalf("failed to parse JWT: %v", err)
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		t.Fatal("claims is not MapClaims")
	}

	if sub, _ := claims["sub"].(string); sub != cfg.DemoAccountUserID {
		t.Errorf("sub = %q, want %q", sub, cfg.DemoAccountUserID)
	}
	if uid, _ := claims["uid"].(string); uid != cfg.DemoAccountUserID {
		t.Errorf("uid = %q, want %q", uid, cfg.DemoAccountUserID)
	}
	if email, _ := claims["email"].(string); email != cfg.DemoAccountEmail {
		t.Errorf("email = %q, want %q", email, cfg.DemoAccountEmail)
	}
	if iss, _ := claims["iss"].(string); iss != "auth-service" {
		t.Errorf("iss = %q, want auth-service", iss)
	}
	aud, _ := claims["aud"].([]interface{})
	if len(aud) == 0 || aud[0] != "makefeed-api" {
		t.Errorf("aud = %v, want [makefeed-api]", aud)
	}
}

func TestAuthHandler_DemoLogin_Disabled(t *testing.T) {
	cfg := newDemoConfig()
	cfg.DemoModeEnabled = false
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "demo@infatium.ru",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusNotFound)
}

func TestAuthHandler_DemoLogin_WrongEmail(t *testing.T) {
	cfg := newDemoConfig()
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "wrong@example.com",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusForbidden)
}

func TestAuthHandler_DemoLogin_MissingUserID(t *testing.T) {
	cfg := newDemoConfig()
	cfg.DemoAccountUserID = ""
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{
		"email": "demo@infatium.ru",
	})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusForbidden)
}

func TestAuthHandler_DemoLogin_MissingEmail(t *testing.T) {
	cfg := newDemoConfig()
	handler := NewAuthHandler(cfg)

	req := newTestRequest(t, http.MethodPost, "/auth/demo-login", map[string]string{})
	rr := httptest.NewRecorder()
	handler.DemoLogin(rr, req)

	assertStatusCode(t, rr.Code, http.StatusBadRequest)
}
