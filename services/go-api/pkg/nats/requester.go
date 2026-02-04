package nats

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

// Requester handles NATS request-reply pattern for RPC calls
type Requester struct {
	nc *nats.Conn
}

func NewRequester(client *Client) *Requester {
	return &Requester{
		nc: client.NC(),
	}
}

// Request sends a request and waits for response
func (r *Requester) Request(ctx context.Context, subject string, request any, timeout time.Duration, headers map[string]string) ([]byte, error) {
	payload, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	msg := nats.NewMsg(subject)
	msg.Data = payload

	for k, v := range headers {
		msg.Header.Set(k, v)
	}

	ctxWithTimeout, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	resp, err := r.nc.RequestMsgWithContext(ctxWithTimeout, msg)
	if err != nil {
		return nil, fmt.Errorf("request to %s: %w", subject, err)
	}

	log.Debug().
		Str("subject", subject).
		Int("response_size", len(resp.Data)).
		Msg("Received NATS response")

	return resp.Data, nil
}

// RequestWithRetry sends request with exponential backoff retry on timeout
func (r *Requester) RequestWithRetry(ctx context.Context, subject string, request any, timeout time.Duration, headers map[string]string, maxRetries int, baseDelay time.Duration) ([]byte, error) {
	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		resp, err := r.Request(ctx, subject, request, timeout, headers)
		if err == nil {
			return resp, nil
		}

		lastErr = err

		// Only retry on timeout errors
		if ctx.Err() != nil {
			return nil, lastErr
		}

		if attempt < maxRetries-1 {
			delay := baseDelay * time.Duration(1<<attempt)
			log.Warn().
				Str("subject", subject).
				Int("attempt", attempt+1).
				Int("max_retries", maxRetries).
				Dur("delay", delay).
				Err(err).
				Msg("Request failed, retrying")

			select {
			case <-time.After(delay):
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		}
	}

	log.Error().
		Str("subject", subject).
		Int("attempts", maxRetries).
		Err(lastErr).
		Msg("All retries failed")

	return nil, lastErr
}
