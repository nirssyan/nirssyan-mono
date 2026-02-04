package telegram

import (
	"context"
	"encoding/json"

	natsgo "github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

const (
	SyncSubject = "telegram.trigger_sync"
	SyncQueue   = "telegram-pollers"
)

type SyncRequest struct{}

type SyncResponse struct {
	Status string `json:"status"`
	Error  string `json:"error,omitempty"`
}

type SyncHandler struct {
	poller *Poller
}

func NewSyncHandler(poller *Poller) *SyncHandler {
	return &SyncHandler{poller: poller}
}

func (h *SyncHandler) Register(nc *natsgo.Conn) error {
	_, err := nc.QueueSubscribe(SyncSubject, SyncQueue, h.handleRequest)
	if err != nil {
		return err
	}

	log.Info().
		Str("subject", SyncSubject).
		Str("queue", SyncQueue).
		Msg("Registered Telegram sync handler")

	return nil
}

func (h *SyncHandler) handleRequest(msg *natsgo.Msg) {
	log.Info().Msg("Received Telegram sync trigger request")

	ctx := context.Background()
	h.poller.pollAllChannels(ctx)

	resp := SyncResponse{Status: "ok"}
	respData, err := json.Marshal(resp)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal sync response")
		return
	}

	if err := msg.Respond(respData); err != nil {
		log.Error().Err(err).Msg("Failed to send sync response")
	}

	log.Info().Msg("Telegram sync trigger completed")
}
