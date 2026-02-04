package service

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidAppleToken = errors.New("invalid apple ID token")
	ErrAppleKeyNotFound  = errors.New("apple public key not found")
)

const appleKeysURL = "https://appleid.apple.com/auth/keys"

type AppleService struct {
	clientID string
	teamID   string
	keyID    string

	keys      map[string]*rsa.PublicKey
	keysMu    sync.RWMutex
	keysExp   time.Time
	keysTTL   time.Duration
	httpClient *http.Client
}

func NewAppleService(clientID, teamID, keyID string) *AppleService {
	return &AppleService{
		clientID:   clientID,
		teamID:     teamID,
		keyID:      keyID,
		keys:       make(map[string]*rsa.PublicKey),
		keysTTL:    24 * time.Hour,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

type AppleClaims struct {
	Sub           string
	Email         string
	EmailVerified bool
}

type appleJWKS struct {
	Keys []appleJWK `json:"keys"`
}

type appleJWK struct {
	KID string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

func (s *AppleService) ValidateIDToken(ctx context.Context, idToken string) (*AppleClaims, error) {
	if err := s.refreshKeysIfNeeded(ctx); err != nil {
		return nil, err
	}

	parts := strings.Split(idToken, ".")
	if len(parts) != 3 {
		return nil, ErrInvalidAppleToken
	}

	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, ErrInvalidAppleToken
	}

	var header struct {
		Kid string `json:"kid"`
		Alg string `json:"alg"`
	}
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, ErrInvalidAppleToken
	}

	s.keysMu.RLock()
	pubKey, ok := s.keys[header.Kid]
	s.keysMu.RUnlock()

	if !ok {
		return nil, ErrAppleKeyNotFound
	}

	token, err := jwt.Parse(idToken, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, ErrInvalidAppleToken
		}
		return pubKey, nil
	})

	if err != nil || !token.Valid {
		return nil, ErrInvalidAppleToken
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, ErrInvalidAppleToken
	}

	iss, _ := claims["iss"].(string)
	if iss != "https://appleid.apple.com" {
		return nil, ErrInvalidAppleToken
	}

	aud, _ := claims["aud"].(string)
	if aud != s.clientID {
		return nil, ErrInvalidAppleToken
	}

	result := &AppleClaims{}
	if sub, ok := claims["sub"].(string); ok {
		result.Sub = sub
	}
	if email, ok := claims["email"].(string); ok {
		result.Email = email
	}
	if emailVerified, ok := claims["email_verified"].(string); ok {
		result.EmailVerified = emailVerified == "true"
	} else if emailVerified, ok := claims["email_verified"].(bool); ok {
		result.EmailVerified = emailVerified
	}

	if result.Sub == "" {
		return nil, ErrInvalidAppleToken
	}

	return result, nil
}

func (s *AppleService) refreshKeysIfNeeded(ctx context.Context) error {
	s.keysMu.RLock()
	if time.Now().Before(s.keysExp) && len(s.keys) > 0 {
		s.keysMu.RUnlock()
		return nil
	}
	s.keysMu.RUnlock()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleKeysURL, nil)
	if err != nil {
		return err
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var jwks appleJWKS
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return err
	}

	newKeys := make(map[string]*rsa.PublicKey)
	for _, jwk := range jwks.Keys {
		if jwk.Kty != "RSA" {
			continue
		}

		nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
		if err != nil {
			continue
		}
		eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
		if err != nil {
			continue
		}

		n := new(big.Int).SetBytes(nBytes)
		e := int(new(big.Int).SetBytes(eBytes).Int64())

		newKeys[jwk.KID] = &rsa.PublicKey{N: n, E: e}
	}

	s.keysMu.Lock()
	s.keys = newKeys
	s.keysExp = time.Now().Add(s.keysTTL)
	s.keysMu.Unlock()

	return nil
}
