package telegram

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/gotd/td/telegram"
	"github.com/gotd/td/telegram/dcs"
	"github.com/gotd/td/tg"
	"github.com/gotd/td/tgerr"
	"github.com/rs/zerolog"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
)

// Client wraps gotd/td for channel message fetching.
type Client struct {
	cfg     *config.Config
	log     zerolog.Logger
	storage *FileStorage

	client *telegram.Client
	api    *tg.Client

	mu        sync.RWMutex
	connected bool

	// Cache for resolved usernames
	chatCache   map[string]*tg.InputPeerChannel
	chatCacheMu sync.RWMutex
}

// NewClient creates a new Telegram client.
func NewClient(cfg *config.Config, log zerolog.Logger) *Client {
	storage := NewFileStorage(cfg.TelegramWorkdir, cfg.TelegramSessionName)

	return &Client{
		cfg:       cfg,
		log:       log.With().Str("component", "telegram_client").Logger(),
		storage:   storage,
		chatCache: make(map[string]*tg.InputPeerChannel),
	}
}

// Connect establishes connection to Telegram.
// Requires existing session file - no interactive auth.
func (c *Client) Connect(ctx context.Context) (err error) {
	defer func() {
		if r := recover(); r != nil {
			c.log.Error().Interface("panic", r).Msg("panic in Telegram Connect")
			err = fmt.Errorf("panic in Connect: %v", r)
			sentry.CaptureException(err)
			sentry.Flush(2 * time.Second)
		}
	}()

	// Check if already connected (read lock only)
	c.mu.RLock()
	if c.connected {
		c.mu.RUnlock()
		return nil
	}
	c.mu.RUnlock()

	c.log.Info().Str("path", c.storage.Path()).Msg("checking session file")

	if !c.storage.Exists() {
		c.log.Error().Str("path", c.storage.Path()).Msg("session file does not exist")
		return &SessionError{
			Op:  "connect",
			Err: ErrSessionExpired,
		}
	}

	c.log.Info().
		Int("api_id", c.cfg.TelegramAPIID).
		Int("api_hash_len", len(c.cfg.TelegramAPIHash)).
		Msg("creating telegram client")

	opts := telegram.Options{
		SessionStorage: c.storage,
		Resolver:       dcs.Plain(dcs.PlainOptions{}),
		// Set reasonable reconnection settings
		RetryInterval: time.Second,
		MaxRetries:    3,
	}

	client := telegram.NewClient(c.cfg.TelegramAPIID, c.cfg.TelegramAPIHash, opts)
	c.client = client

	c.log.Info().Msg("telegram client created, starting Run()")

	// Run client in background
	errCh := make(chan error, 1)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				c.log.Error().Interface("panic", r).Msg("panic in client.Run goroutine")
				panicErr := fmt.Errorf("panic in client.Run: %v", r)
				sentry.CaptureException(panicErr)
				sentry.Flush(2 * time.Second)
				errCh <- panicErr
			}
		}()

		c.log.Info().Msg("starting client.Run()")
		errCh <- client.Run(ctx, func(ctx context.Context) error {
			c.log.Info().Msg("inside client.Run callback")

			// Skip auth status check - it often blocks forever with gotd/td
			// If the session is invalid, API calls will fail with auth errors
			// and we'll handle that at the call site
			c.mu.Lock()
			c.api = client.API()
			c.connected = true
			c.mu.Unlock()

			c.log.Info().Msg("connected to Telegram (session loaded)")

			// Block until context cancelled
			<-ctx.Done()
			return ctx.Err()
		})
	}()

	// Wait for connection or error
	select {
	case err := <-errCh:
		return err
	case <-time.After(10 * time.Second):
		if !c.IsConnected() {
			return &SessionError{Op: "connect", Err: context.DeadlineExceeded}
		}
	case <-ctx.Done():
		return ctx.Err()
	}

	return nil
}

// IsConnected returns connection status.
func (c *Client) IsConnected() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.connected
}

// GetChatHistory fetches messages from a channel.
func (c *Client) GetChatHistory(
	ctx context.Context,
	peer *tg.InputPeerChannel,
	limit int,
	offsetID int,
) ([]tg.MessageClass, error) {
	c.mu.RLock()
	api := c.api
	connected := c.connected
	c.mu.RUnlock()

	if !connected || api == nil {
		return nil, ErrNotConnected
	}

	req := &tg.MessagesGetHistoryRequest{
		Peer:     peer,
		Limit:    limit,
		OffsetID: offsetID,
	}

	result, err := api.MessagesGetHistory(ctx, req)
	if err != nil {
		if floodErr := extractFloodWait(err); floodErr != nil {
			return nil, floodErr
		}
		return nil, err
	}

	switch v := result.(type) {
	case *tg.MessagesMessages:
		return v.Messages, nil
	case *tg.MessagesMessagesSlice:
		return v.Messages, nil
	case *tg.MessagesChannelMessages:
		return v.Messages, nil
	default:
		return nil, nil
	}
}

// ResolveUsername resolves @username to InputPeerChannel with caching.
func (c *Client) ResolveUsername(ctx context.Context, username string) (*tg.InputPeerChannel, error) {
	username = strings.TrimPrefix(username, "@")

	// Check cache
	c.chatCacheMu.RLock()
	if peer, ok := c.chatCache[username]; ok {
		c.chatCacheMu.RUnlock()
		return peer, nil
	}
	c.chatCacheMu.RUnlock()

	c.mu.RLock()
	api := c.api
	connected := c.connected
	c.mu.RUnlock()

	if !connected || api == nil {
		return nil, ErrNotConnected
	}

	resolved, err := api.ContactsResolveUsername(ctx, &tg.ContactsResolveUsernameRequest{
		Username: username,
	})
	if err != nil {
		if floodErr := extractFloodWait(err); floodErr != nil {
			return nil, floodErr
		}
		return nil, &ChannelUnavailableError{
			Username: username,
			Reason:   err.Error(),
		}
	}

	// Find channel in chats
	for _, chat := range resolved.Chats {
		if ch, ok := chat.(*tg.Channel); ok {
			peer := &tg.InputPeerChannel{
				ChannelID:  ch.ID,
				AccessHash: ch.AccessHash,
			}

			// Cache result
			c.chatCacheMu.Lock()
			c.chatCache[username] = peer
			c.chatCacheMu.Unlock()

			return peer, nil
		}
	}

	return nil, &ChannelUnavailableError{
		Username: username,
		Reason:   "not a channel",
	}
}

// GetChannelInfo returns channel metadata.
func (c *Client) GetChannelInfo(ctx context.Context, username string) (*ChannelInfo, error) {
	username = strings.TrimPrefix(username, "@")

	c.mu.RLock()
	api := c.api
	connected := c.connected
	c.mu.RUnlock()

	if !connected || api == nil {
		return nil, ErrNotConnected
	}

	resolved, err := api.ContactsResolveUsername(ctx, &tg.ContactsResolveUsernameRequest{
		Username: username,
	})
	if err != nil {
		if floodErr := extractFloodWait(err); floodErr != nil {
			return nil, floodErr
		}
		return nil, &ChannelUnavailableError{
			Username: username,
			Reason:   err.Error(),
		}
	}

	for _, chat := range resolved.Chats {
		if ch, ok := chat.(*tg.Channel); ok {
			return &ChannelInfo{
				ID:       ch.ID,
				Title:    ch.Title,
				Username: ch.Username,
			}, nil
		}
	}

	return nil, ErrChannelNotFound
}

// Close disconnects the client.
func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.connected = false
	c.api = nil
	return nil
}

// ChannelInfo holds channel metadata.
type ChannelInfo struct {
	ID       int64
	Title    string
	Username string
}

// extractFloodWait checks if error is FloodWait and returns typed error.
func extractFloodWait(err error) *FloodWaitError {
	if d, ok := tgerr.AsFloodWait(err); ok {
		return &FloodWaitError{Seconds: int(d.Seconds())}
	}
	return nil
}
