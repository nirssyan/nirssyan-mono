package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

func TestNewAuthMiddleware(t *testing.T) {
	m := NewAuthMiddleware("secret")
	if m == nil {
		t.Fatal("NewAuthMiddleware returned nil")
	}
	if string(m.jwtSecret) != "secret" {
		t.Errorf("jwtSecret = %q, want secret", m.jwtSecret)
	}
}

func TestGetUserID_NoContext(t *testing.T) {
	ctx := context.Background()
	userID, ok := GetUserID(ctx)

	if ok {
		t.Error("expected ok=false")
	}
	if userID != uuid.Nil {
		t.Errorf("userID = %v, want nil uuid", userID)
	}
}

func TestGetUserID_WithContext(t *testing.T) {
	expectedID := uuid.New()
	ctx := context.WithValue(context.Background(), UserIDKey, expectedID)

	userID, ok := GetUserID(ctx)

	if !ok {
		t.Error("expected ok=true")
	}
	if userID != expectedID {
		t.Errorf("userID = %v, want %v", userID, expectedID)
	}
}

func TestAuthenticate_MissingHeader(t *testing.T) {
	m := NewAuthMiddleware("secret")
	handler := m.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusUnauthorized)
	}
}

func TestAuthenticate_InvalidFormat(t *testing.T) {
	tests := []struct {
		name   string
		header string
	}{
		{"missing bearer", "token-without-bearer"},
		{"wrong prefix", "Basic token123"},
		{"too many parts", "Bearer token extra"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m := NewAuthMiddleware("secret")
			handler := m.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				t.Error("handler should not be called")
			}))

			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Header.Set("Authorization", tt.header)
			rr := httptest.NewRecorder()

			handler.ServeHTTP(rr, req)

			if rr.Code != http.StatusUnauthorized {
				t.Errorf("status = %d, want %d", rr.Code, http.StatusUnauthorized)
			}
		})
	}
}

func TestAuthenticate_InvalidToken(t *testing.T) {
	m := NewAuthMiddleware("secret")
	handler := m.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer invalid.token.here")
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusUnauthorized)
	}
}

func TestAuthenticate_ValidToken(t *testing.T) {
	secret := "test-secret"
	userID := uuid.New()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("failed to sign token: %v", err)
	}

	var gotUserID uuid.UUID
	m := NewAuthMiddleware(secret)
	handler := m.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := GetUserID(r.Context())
		if !ok {
			t.Error("expected user id in context")
		}
		gotUserID = id
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenString)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusOK)
	}
	if gotUserID != userID {
		t.Errorf("user id = %v, want %v", gotUserID, userID)
	}
}

func TestOptionalAuth_NoHeader(t *testing.T) {
	m := NewAuthMiddleware("secret")
	called := false
	handler := m.OptionalAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		_, ok := GetUserID(r.Context())
		if ok {
			t.Error("expected no user id in context")
		}
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if !called {
		t.Error("handler was not called")
	}
	if rr.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusOK)
	}
}

func TestOptionalAuth_InvalidToken(t *testing.T) {
	m := NewAuthMiddleware("secret")
	called := false
	handler := m.OptionalAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		_, ok := GetUserID(r.Context())
		if ok {
			t.Error("expected no user id in context for invalid token")
		}
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer invalid.token.here")
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if !called {
		t.Error("handler was not called")
	}
	if rr.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusOK)
	}
}

func TestOptionalAuth_ValidToken(t *testing.T) {
	secret := "test-secret"
	userID := uuid.New()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("failed to sign token: %v", err)
	}

	var gotUserID uuid.UUID
	var gotOK bool
	m := NewAuthMiddleware(secret)
	handler := m.OptionalAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUserID, gotOK = GetUserID(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenString)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rr.Code, http.StatusOK)
	}
	if !gotOK {
		t.Error("expected user id in context")
	}
	if gotUserID != userID {
		t.Errorf("user id = %v, want %v", gotUserID, userID)
	}
}

func TestValidateJWT_Valid(t *testing.T) {
	secret := "test-secret"
	userID := uuid.New()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("failed to sign token: %v", err)
	}

	gotUserID, err := ValidateJWT(tokenString, secret)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if gotUserID != userID {
		t.Errorf("user id = %v, want %v", gotUserID, userID)
	}
}

func TestValidateJWT_InvalidToken(t *testing.T) {
	_, err := ValidateJWT("invalid.token.here", "secret")
	if err == nil {
		t.Error("expected error for invalid token")
	}
}

func TestValidateJWT_WrongSecret(t *testing.T) {
	userID := uuid.New()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	tokenString, err := token.SignedString([]byte("correct-secret"))
	if err != nil {
		t.Fatalf("failed to sign token: %v", err)
	}

	_, err = ValidateJWT(tokenString, "wrong-secret")
	if err == nil {
		t.Error("expected error for wrong secret")
	}
}
