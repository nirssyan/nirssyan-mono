package clients

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha512"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/rs/zerolog/log"
)

type RuStoreSubscriptionResponse struct {
	StartTimeMillis     int64  `json:"startTimeMillis"`
	ExpiryTimeMillis    int64  `json:"expiryTimeMillis"`
	AutoRenewing        bool   `json:"autoRenewing"`
	PriceAmountMicros   int64  `json:"priceAmountMicros"`
	PriceCurrencyCode   string `json:"priceCurrencyCode"`
	PaymentState        int    `json:"paymentState"`
	OrderID             string `json:"orderId"`
	AcknowledgementState int   `json:"acknowledgementState"`
	CancelReason        *int   `json:"cancelReason,omitempty"`
}

type RuStoreAPIResponse struct {
	Code    string                       `json:"code"`
	Message string                       `json:"message,omitempty"`
	Body    *RuStoreSubscriptionResponse `json:"body,omitempty"`
}

type RuStoreAuthResponse struct {
	Code string `json:"code"`
	Body struct {
		JWE string `json:"jwe"`
	} `json:"body"`
}

type RuStoreClient struct {
	keyID         string
	privateKey    *rsa.PrivateKey
	httpClient    *http.Client
	cachedToken   string
	tokenExpiry   time.Time
	tokenMutex    sync.RWMutex
}

func NewRuStoreClient(keyID, privateKeyPath, privateKeyPEM string) (*RuStoreClient, error) {
	client := &RuStoreClient{
		keyID:      keyID,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}

	if privateKeyPath != "" {
		keyData, err := os.ReadFile(privateKeyPath)
		if err != nil {
			log.Warn().Err(err).Str("path", privateKeyPath).Msg("Failed to read private key file")
		} else {
			privateKeyPEM = string(keyData)
		}
	}

	if privateKeyPEM != "" {
		block, _ := pem.Decode([]byte(privateKeyPEM))
		if block == nil {
			return nil, fmt.Errorf("failed to decode PEM block")
		}

		var privateKey *rsa.PrivateKey
		var err error

		switch block.Type {
		case "RSA PRIVATE KEY":
			privateKey, err = x509.ParsePKCS1PrivateKey(block.Bytes)
		case "PRIVATE KEY":
			key, e := x509.ParsePKCS8PrivateKey(block.Bytes)
			if e != nil {
				err = e
			} else {
				var ok bool
				privateKey, ok = key.(*rsa.PrivateKey)
				if !ok {
					err = fmt.Errorf("not an RSA private key")
				}
			}
		default:
			err = fmt.Errorf("unsupported PEM type: %s", block.Type)
		}

		if err != nil {
			return nil, fmt.Errorf("failed to parse private key: %w", err)
		}

		client.privateKey = privateKey
	}

	return client, nil
}

func (c *RuStoreClient) getAuthToken(ctx context.Context) (string, error) {
	c.tokenMutex.RLock()
	if c.cachedToken != "" && time.Now().Before(c.tokenExpiry) {
		token := c.cachedToken
		c.tokenMutex.RUnlock()
		return token, nil
	}
	c.tokenMutex.RUnlock()

	c.tokenMutex.Lock()
	defer c.tokenMutex.Unlock()

	if c.cachedToken != "" && time.Now().Before(c.tokenExpiry) {
		return c.cachedToken, nil
	}

	if c.privateKey == nil || c.keyID == "" {
		return "", fmt.Errorf("RuStore credentials not configured")
	}

	timestamp := fmt.Sprintf("%d", time.Now().Unix())

	hashed := sha512.Sum512([]byte(c.keyID + timestamp))
	signature, err := rsa.SignPKCS1v15(rand.Reader, c.privateKey, crypto.SHA512, hashed[:])
	if err != nil {
		return "", fmt.Errorf("failed to sign: %w", err)
	}

	signatureBase64 := base64.StdEncoding.EncodeToString(signature)

	reqBody := fmt.Sprintf(`{"keyId":"%s","timestamp":"%s","signature":"%s"}`, c.keyID, timestamp, signatureBase64)

	req, err := http.NewRequestWithContext(ctx, "POST", "https://public-api.rustore.ru/public/auth/", strings.NewReader(reqBody))
	if err != nil {
		return "", fmt.Errorf("failed to create auth request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("auth request failed: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("auth failed with status %d: %s", resp.StatusCode, string(body))
	}

	var authResp RuStoreAuthResponse
	if err := json.Unmarshal(body, &authResp); err != nil {
		return "", fmt.Errorf("failed to parse auth response: %w", err)
	}

	if authResp.Code != "OK" {
		return "", fmt.Errorf("auth failed: %s", authResp.Code)
	}

	c.cachedToken = authResp.Body.JWE
	c.tokenExpiry = time.Now().Add(800 * time.Second)

	return c.cachedToken, nil
}

func (c *RuStoreClient) ValidateSubscription(ctx context.Context, packageName, subscriptionID, purchaseToken string) (*RuStoreSubscriptionResponse, error) {
	token, err := c.getAuthToken(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get auth token: %w", err)
	}

	url := fmt.Sprintf("https://public-api.rustore.ru/public/v3/subscription/%s/%s/%s",
		packageName, subscriptionID, purchaseToken)

	log.Info().
		Str("package", packageName).
		Str("subscription_id", subscriptionID).
		Str("purchase_token", purchaseToken).
		Msg("Validating RuStore subscription")

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Public-Token", token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	log.Info().
		Int("status", resp.StatusCode).
		Str("body", string(body)).
		Msg("RuStore API response")

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var apiResp RuStoreAPIResponse
	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	if apiResp.Code != "OK" {
		return nil, fmt.Errorf("API error: %s - %s", apiResp.Code, apiResp.Message)
	}

	if apiResp.Body == nil {
		return nil, fmt.Errorf("empty response body")
	}

	return apiResp.Body, nil
}
