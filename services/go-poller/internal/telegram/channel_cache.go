package telegram

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"
)

const channelCacheKeyPrefix = "channel:"

// CachedChannel holds channel data stored in Redis.
type CachedChannel struct {
	ChatID     int64  `json:"chat_id"`
	AccessHash int64  `json:"access_hash"`
	Username   string `json:"username"`
	Title      string `json:"title"`
}

// ChannelCache provides Redis-based caching for resolved Telegram channels.
type ChannelCache struct {
	client *redis.Client
	ttl    time.Duration
	log    zerolog.Logger
}

// NewChannelCache creates a new channel cache from Redis URL.
// Returns nil if redisURL is empty (cache disabled).
func NewChannelCache(redisURL string, ttlSeconds int, log zerolog.Logger) (*ChannelCache, error) {
	if redisURL == "" {
		log.Info().Msg("Redis URL not configured, channel cache disabled")
		return nil, nil
	}

	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis URL: %w", err)
	}

	client := redis.NewClient(opts)

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping failed: %w", err)
	}

	log.Info().
		Int("ttl_seconds", ttlSeconds).
		Msg("Channel cache initialized")

	return &ChannelCache{
		client: client,
		ttl:    time.Duration(ttlSeconds) * time.Second,
		log:    log.With().Str("component", "channel_cache").Logger(),
	}, nil
}

// Get retrieves cached channel info by username.
func (c *ChannelCache) Get(ctx context.Context, username string) (*CachedChannel, error) {
	if c == nil {
		return nil, nil
	}

	key := channelCacheKeyPrefix + strings.ToLower(username)
	data, err := c.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("redis get: %w", err)
	}

	var cached CachedChannel
	if err := json.Unmarshal([]byte(data), &cached); err != nil {
		c.log.Warn().Err(err).Str("username", username).Msg("Failed to unmarshal cached channel")
		return nil, nil
	}

	c.log.Info().Str("username", username).Int64("chat_id", cached.ChatID).Msg("Channel cache HIT")
	return &cached, nil
}

// Set stores channel info in cache.
func (c *ChannelCache) Set(ctx context.Context, username string, chatID, accessHash int64, title string) error {
	if c == nil {
		return nil
	}

	key := channelCacheKeyPrefix + strings.ToLower(username)
	data, err := json.Marshal(CachedChannel{
		ChatID:     chatID,
		AccessHash: accessHash,
		Username:   username,
		Title:      title,
	})
	if err != nil {
		return fmt.Errorf("marshal channel: %w", err)
	}

	if err := c.client.SetEx(ctx, key, data, c.ttl).Err(); err != nil {
		return fmt.Errorf("redis setex: %w", err)
	}

	c.log.Info().Str("username", username).Int64("chat_id", chatID).Msg("Channel cached")
	return nil
}

// Close closes the Redis connection.
func (c *ChannelCache) Close() error {
	if c == nil {
		return nil
	}
	return c.client.Close()
}
