package nats

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/rs/zerolog/log"
)

type MessageHandler func(ctx context.Context, msg jetstream.Msg) error

type Subscriber struct {
	js jetstream.JetStream
}

func NewSubscriber(client *Client) *Subscriber {
	return &Subscriber{
		js: client.JetStream(),
	}
}

func (s *Subscriber) Subscribe(
	ctx context.Context,
	stream string,
	consumer string,
	handler MessageHandler,
) (jetstream.ConsumeContext, error) {
	cons, err := s.js.CreateOrUpdateConsumer(ctx, stream, jetstream.ConsumerConfig{
		Durable:       consumer,
		AckPolicy:     jetstream.AckExplicitPolicy,
		DeliverPolicy: jetstream.DeliverNewPolicy,
	})
	if err != nil {
		return nil, fmt.Errorf("create consumer %s: %w", consumer, err)
	}

	consumeCtx, err := cons.Consume(func(msg jetstream.Msg) {
		if err := handler(ctx, msg); err != nil {
			log.Error().Err(err).Str("subject", msg.Subject()).Msg("Error handling message")
			if nakErr := msg.Nak(); nakErr != nil {
				log.Error().Err(nakErr).Msg("Error sending NAK")
			}
			return
		}

		if err := msg.Ack(); err != nil {
			log.Error().Err(err).Msg("Error sending ACK")
		}
	})
	if err != nil {
		return nil, fmt.Errorf("consume: %w", err)
	}

	log.Info().Str("stream", stream).Str("consumer", consumer).Msg("Subscribed to stream")
	return consumeCtx, nil
}

type RequestReplyHandler[Req any, Resp any] func(ctx context.Context, req Req) (Resp, error)

func HandleRequestReply[Req any, Resp any](
	ctx context.Context,
	client *Client,
	subject string,
	queue string,
	handler RequestReplyHandler[Req, Resp],
) error {
	_, err := client.NC().QueueSubscribe(subject, queue, func(msg *nats.Msg) {
		var req Req
		if err := json.Unmarshal(msg.Data, &req); err != nil {
			log.Error().Err(err).Str("subject", subject).Msg("Error unmarshaling request")
			return
		}

		resp, err := handler(ctx, req)
		if err != nil {
			log.Error().Err(err).Str("subject", subject).Msg("Error handling request")
			return
		}

		respData, err := json.Marshal(resp)
		if err != nil {
			log.Error().Err(err).Str("subject", subject).Msg("Error marshaling response")
			return
		}

		if err := msg.Respond(respData); err != nil {
			log.Error().Err(err).Str("subject", subject).Msg("Error sending response")
		}
	})

	if err != nil {
		return fmt.Errorf("subscribe to %s: %w", subject, err)
	}

	log.Info().Str("subject", subject).Str("queue", queue).Msg("Registered request-reply handler")
	return nil
}
