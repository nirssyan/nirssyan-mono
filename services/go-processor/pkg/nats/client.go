package nats

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/rs/zerolog/log"
)

type Client struct {
	nc *nats.Conn
	js jetstream.JetStream

	mu        sync.RWMutex
	connected bool
}

type ClientConfig struct {
	URL                  string
	Name                 string
	ConnectTimeout       time.Duration
	ReconnectWait        time.Duration
	MaxReconnectAttempts int
}

func NewClient(ctx context.Context, cfg ClientConfig) (*Client, error) {
	if cfg.ConnectTimeout == 0 {
		cfg.ConnectTimeout = 10 * time.Second
	}
	if cfg.ReconnectWait == 0 {
		cfg.ReconnectWait = 2 * time.Second
	}
	if cfg.MaxReconnectAttempts == 0 {
		cfg.MaxReconnectAttempts = 60
	}

	c := &Client{}

	opts := []nats.Option{
		nats.Timeout(cfg.ConnectTimeout),
		nats.ReconnectWait(cfg.ReconnectWait),
		nats.MaxReconnects(cfg.MaxReconnectAttempts),
		nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
			log.Warn().Err(err).Msg("NATS disconnected")
			c.mu.Lock()
			c.connected = false
			c.mu.Unlock()
		}),
		nats.ReconnectHandler(func(_ *nats.Conn) {
			log.Info().Msg("NATS reconnected")
			c.mu.Lock()
			c.connected = true
			c.mu.Unlock()
		}),
		nats.ClosedHandler(func(_ *nats.Conn) {
			log.Info().Msg("NATS connection closed")
		}),
		nats.ErrorHandler(func(_ *nats.Conn, _ *nats.Subscription, err error) {
			log.Error().Err(err).Msg("NATS error")
		}),
	}

	if cfg.Name != "" {
		opts = append(opts, nats.Name(cfg.Name))
	}

	nc, err := nats.Connect(cfg.URL, opts...)
	if err != nil {
		return nil, fmt.Errorf("connect to nats: %w", err)
	}

	js, err := jetstream.New(nc)
	if err != nil {
		nc.Close()
		return nil, fmt.Errorf("create jetstream context: %w", err)
	}

	c.nc = nc
	c.js = js
	c.connected = true

	log.Info().Str("url", cfg.URL).Msg("Connected to NATS")

	return c, nil
}

func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.nc != nil {
		if err := c.nc.Drain(); err != nil {
			log.Warn().Err(err).Msg("Error draining NATS connection")
		}
		c.nc.Close()
		c.connected = false
	}

	log.Info().Msg("NATS client closed")
	return nil
}

func (c *Client) IsConnected() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.connected && c.nc != nil && c.nc.IsConnected()
}

func (c *Client) JetStream() jetstream.JetStream {
	return c.js
}

func (c *Client) NC() *nats.Conn {
	return c.nc
}

func (c *Client) EnsureStream(ctx context.Context, name string, subjects []string, retention jetstream.RetentionPolicy, maxAge time.Duration) (jetstream.Stream, error) {
	cfg := jetstream.StreamConfig{
		Name:       name,
		Subjects:   subjects,
		Retention:  retention,
		MaxAge:     maxAge,
		MaxBytes:   1 * 1024 * 1024 * 1024, // 1GB
		Storage:    jetstream.FileStorage,
		Replicas:   1,
	}

	stream, err := c.js.Stream(ctx, name)
	if err == nil {
		log.Debug().Str("stream", name).Msg("Stream already exists")
		return stream, nil
	}

	stream, err = c.js.CreateStream(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create stream %s: %w", name, err)
	}

	log.Info().Str("stream", name).Strs("subjects", subjects).Msg("Created stream")
	return stream, nil
}
