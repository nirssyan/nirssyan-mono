package service

import (
	"context"
	"errors"

	"google.golang.org/api/idtoken"
)

var ErrInvalidGoogleToken = errors.New("invalid google ID token")

type GoogleService struct {
	clientID string
}

func NewGoogleService(clientID string) *GoogleService {
	return &GoogleService{clientID: clientID}
}

type GoogleClaims struct {
	Sub           string
	Email         string
	EmailVerified bool
	Name          string
	Picture       string
}

func (s *GoogleService) ValidateIDToken(ctx context.Context, idToken string) (*GoogleClaims, error) {
	payload, err := idtoken.Validate(ctx, idToken, s.clientID)
	if err != nil {
		return nil, ErrInvalidGoogleToken
	}

	claims := &GoogleClaims{
		Sub: payload.Subject,
	}

	if email, ok := payload.Claims["email"].(string); ok {
		claims.Email = email
	}
	if emailVerified, ok := payload.Claims["email_verified"].(bool); ok {
		claims.EmailVerified = emailVerified
	}
	if name, ok := payload.Claims["name"].(string); ok {
		claims.Name = name
	}
	if picture, ok := payload.Claims["picture"].(string); ok {
		claims.Picture = picture
	}

	if claims.Sub == "" || claims.Email == "" {
		return nil, ErrInvalidGoogleToken
	}

	return claims, nil
}
