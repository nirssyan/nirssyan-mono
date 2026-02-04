package nats

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/rs/zerolog/log"
)

type Publisher struct {
	js      jetstream.JetStream
	enabled bool
}

func NewPublisher(client *Client, enabled bool) *Publisher {
	return &Publisher{
		js:      client.JetStream(),
		enabled: enabled,
	}
}

func (p *Publisher) Publish(ctx context.Context, subject string, data interface{}) error {
	if !p.enabled {
		log.Debug().Str("subject", subject).Msg("NATS publishing disabled, skipping")
		return nil
	}

	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshal message: %w", err)
	}

	ack, err := p.js.Publish(ctx, subject, payload)
	if err != nil {
		return fmt.Errorf("publish to %s: %w", subject, err)
	}

	observability.IncNATSPublished(subject)

	log.Debug().
		Str("subject", subject).
		Str("stream", ack.Stream).
		Uint64("seq", ack.Sequence).
		Msg("Published message to NATS")

	return nil
}

func (p *Publisher) IsEnabled() bool {
	return p.enabled
}
