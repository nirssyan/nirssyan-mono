package hmac

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"strings"
)

var (
	ErrSecretNotConfigured = errors.New("webhook secret not configured")
	ErrInvalidSignature    = errors.New("invalid signature")
)

func VerifyAppStoreSignature(payload []byte, signature, secret string) error {
	if secret == "" {
		return ErrSecretNotConfigured
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	actualSignature := signature
	if strings.HasPrefix(signature, "hmacsha256=") {
		actualSignature = signature[11:]
	}

	if subtle.ConstantTimeCompare([]byte(expectedSignature), []byte(actualSignature)) != 1 {
		return ErrInvalidSignature
	}

	return nil
}
