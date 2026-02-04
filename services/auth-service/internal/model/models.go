package model

import (
	"net"
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID              uuid.UUID  `json:"id"`
	Email           string     `json:"email"`
	Provider        string     `json:"provider"`
	ProviderID      *string    `json:"provider_id,omitempty"`
	PasswordHash    *string    `json:"-"`
	EmailVerifiedAt *time.Time `json:"email_verified_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type TokenFamily struct {
	ID           uuid.UUID  `json:"id"`
	UserID       uuid.UUID  `json:"user_id"`
	Revoked      bool       `json:"revoked"`
	RevokedAt    *time.Time `json:"revoked_at,omitempty"`
	RevokeReason *string    `json:"revoke_reason,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

type RefreshToken struct {
	ID         uuid.UUID `json:"id"`
	TokenHash  string    `json:"-"`
	UserID     uuid.UUID `json:"user_id"`
	FamilyID   uuid.UUID `json:"family_id"`
	Used       bool      `json:"used"`
	DeviceInfo *string   `json:"device_info,omitempty"`
	IPAddress  net.IP    `json:"ip_address,omitempty"`
	ExpiresAt  time.Time `json:"expires_at"`
	CreatedAt  time.Time `json:"created_at"`
}

type MagicLinkToken struct {
	ID        uuid.UUID  `json:"id"`
	Email     string     `json:"email"`
	TokenHash string     `json:"-"`
	UserID    *uuid.UUID `json:"user_id,omitempty"`
	ExpiresAt time.Time  `json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

type AuthResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	TokenType    string `json:"token_type"`
	User         *User  `json:"user,omitempty"`
}

type GoogleAuthRequest struct {
	IDToken string `json:"id_token"`
}

type AppleAuthRequest struct {
	IDToken string `json:"id_token"`
}

type MagicLinkRequest struct {
	Email string `json:"email"`
}

type VerifyRequest struct {
	Token string `json:"token"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}
