package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
)

type RawFeedRepository struct {
	pool *pgxpool.Pool
}

func NewRawFeedRepository(pool *pgxpool.Pool) *RawFeedRepository {
	return &RawFeedRepository{pool: pool}
}

func (r *RawFeedRepository) GetRSSFeedsDueForPoll(ctx context.Context, tierIntervals map[string]int) ([]domain.RawFeed, error) {
	var allFeeds []domain.RawFeed

	for tier, intervalSeconds := range tierIntervals {
		query := `
			SELECT
				id, name, raw_type, feed_url, site_url, image_url,
				telegram_chat_id, telegram_username,
				last_execution, last_polled_at, last_message_id,
				poll_error_count, polling_tier, priority_boost_until, last_flood_wait_at, created_at
			FROM raw_feeds
			WHERE raw_type = 'RSS'
			  AND polling_tier = $1
			  AND feed_url IS NOT NULL
			  AND (last_polled_at IS NULL OR last_polled_at < NOW() - INTERVAL '1 second' * $2)
			ORDER BY last_polled_at ASC NULLS FIRST
			LIMIT 50
		`

		rows, err := r.pool.Query(ctx, query, tier, intervalSeconds)
		if err != nil {
			return nil, fmt.Errorf("query rss feeds tier %s: %w", tier, err)
		}

		feeds, err := scanRawFeeds(rows)
		rows.Close()
		if err != nil {
			return nil, err
		}

		allFeeds = append(allFeeds, feeds...)
	}

	return allFeeds, nil
}

func (r *RawFeedRepository) GetWebFeedsDueForPoll(ctx context.Context, tierIntervals map[string]int) ([]domain.RawFeed, error) {
	var allFeeds []domain.RawFeed

	for tier, intervalSeconds := range tierIntervals {
		query := `
			SELECT
				id, name, raw_type, feed_url, site_url, image_url,
				telegram_chat_id, telegram_username,
				last_execution, last_polled_at, last_message_id,
				poll_error_count, polling_tier, priority_boost_until, last_flood_wait_at, created_at
			FROM raw_feeds
			WHERE raw_type = 'WEBSITE'
			  AND polling_tier = $1
			  AND (last_polled_at IS NULL OR last_polled_at < NOW() - INTERVAL '1 second' * $2)
			ORDER BY last_polled_at ASC NULLS FIRST
			LIMIT 50
		`

		rows, err := r.pool.Query(ctx, query, tier, intervalSeconds)
		if err != nil {
			return nil, fmt.Errorf("query web feeds tier %s: %w", tier, err)
		}

		feeds, err := scanRawFeeds(rows)
		rows.Close()
		if err != nil {
			return nil, err
		}

		allFeeds = append(allFeeds, feeds...)
	}

	return allFeeds, nil
}

func (r *RawFeedRepository) GetTelegramFeedsDueForPoll(
	ctx context.Context,
	tierIntervals map[string]int,
	floodWaitCooldownSeconds int,
) ([]domain.RawFeed, error) {
	query := `
		WITH effective_tiers AS (
			SELECT
				id, name, raw_type, feed_url, site_url, image_url,
				telegram_chat_id, telegram_username,
				last_execution, last_polled_at, last_message_id,
				poll_error_count, polling_tier, priority_boost_until, last_flood_wait_at, created_at,
				CASE
					WHEN priority_boost_until > NOW() THEN 'HOT'
					ELSE polling_tier
				END AS effective_tier
			FROM raw_feeds
			WHERE raw_type = 'TELEGRAM'
			  AND telegram_chat_id IS NOT NULL
		)
		SELECT
			id, name, raw_type, feed_url, site_url, image_url,
			telegram_chat_id, telegram_username,
			last_execution, last_polled_at, last_message_id,
			poll_error_count, polling_tier, priority_boost_until, last_flood_wait_at, created_at
		FROM effective_tiers
		WHERE (
			last_polled_at IS NULL
			OR (effective_tier = 'HOT' AND last_polled_at < NOW() - INTERVAL '1 second' * $1)
			OR (effective_tier = 'WARM' AND last_polled_at < NOW() - INTERVAL '1 second' * $2)
			OR (effective_tier = 'COLD' AND last_polled_at < NOW() - INTERVAL '1 second' * $3)
			OR (effective_tier = 'QUARANTINE' AND last_polled_at < NOW() - INTERVAL '1 second' * $4)
		)
		AND (last_flood_wait_at IS NULL OR last_flood_wait_at < NOW() - INTERVAL '1 second' * $5)
		ORDER BY
			CASE effective_tier
				WHEN 'HOT' THEN 1
				WHEN 'WARM' THEN 2
				WHEN 'COLD' THEN 3
				WHEN 'QUARANTINE' THEN 4
				ELSE 5
			END ASC,
			last_polled_at ASC NULLS FIRST
		LIMIT 50
	`

	rows, err := r.pool.Query(
		ctx, query,
		tierIntervals["HOT"],
		tierIntervals["WARM"],
		tierIntervals["COLD"],
		tierIntervals["QUARANTINE"],
		floodWaitCooldownSeconds,
	)
	if err != nil {
		return nil, fmt.Errorf("query telegram feeds: %w", err)
	}
	defer rows.Close()

	return scanRawFeeds(rows)
}

func (r *RawFeedRepository) UpdatePollResult(ctx context.Context, feedID uuid.UUID, newPostsCount int, hasError bool, errorMsg string) error {
	var query string
	var args []interface{}

	if hasError {
		query = `
			UPDATE raw_feeds
			SET last_execution = NOW(),
				last_polled_at = NOW(),
				poll_error_count = poll_error_count + 1
			WHERE id = $1
		`
		args = []interface{}{feedID}
	} else {
		query = `
			UPDATE raw_feeds
			SET last_execution = NOW(),
				last_polled_at = NOW(),
				poll_error_count = 0
			WHERE id = $1
		`
		args = []interface{}{feedID}
	}

	_, err := r.pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("update poll result: %w", err)
	}

	return nil
}

func (r *RawFeedRepository) UpdateTelegramPollMetadata(
	ctx context.Context,
	feedID uuid.UUID,
	lastMessageID *int64,
	errorOccurred bool,
	isFloodWait bool,
) error {
	var query string
	var args []interface{}

	if errorOccurred {
		if isFloodWait {
			query = `
				UPDATE raw_feeds
				SET last_polled_at = NOW(),
					poll_error_count = poll_error_count + 1,
					last_flood_wait_at = NOW(),
					polling_tier = CASE
						WHEN poll_error_count + 1 > 5 THEN 'QUARANTINE'
						ELSE polling_tier
					END,
					tier_updated_at = CASE
						WHEN poll_error_count + 1 > 5 THEN NOW()
						ELSE tier_updated_at
					END
				WHERE id = $1
			`
		} else {
			query = `
				UPDATE raw_feeds
				SET last_polled_at = NOW(),
					poll_error_count = poll_error_count + 1,
					polling_tier = CASE
						WHEN poll_error_count + 1 > 5 THEN 'QUARANTINE'
						ELSE polling_tier
					END,
					tier_updated_at = CASE
						WHEN poll_error_count + 1 > 5 THEN NOW()
						ELSE tier_updated_at
					END
				WHERE id = $1
			`
		}
		args = []interface{}{feedID}
	} else {
		if lastMessageID != nil {
			query = `
				UPDATE raw_feeds
				SET last_polled_at = NOW(),
					poll_error_count = 0,
					last_message_id = $2,
					polling_tier = CASE
						WHEN polling_tier = 'QUARANTINE' THEN 'COLD'
						ELSE polling_tier
					END,
					tier_updated_at = CASE
						WHEN polling_tier = 'QUARANTINE' THEN NOW()
						ELSE tier_updated_at
					END
				WHERE id = $1
			`
			args = []interface{}{feedID, fmt.Sprintf("%d", *lastMessageID)}
		} else {
			query = `
				UPDATE raw_feeds
				SET last_polled_at = NOW(),
					poll_error_count = 0,
					polling_tier = CASE
						WHEN polling_tier = 'QUARANTINE' THEN 'COLD'
						ELSE polling_tier
					END,
					tier_updated_at = CASE
						WHEN polling_tier = 'QUARANTINE' THEN NOW()
						ELSE tier_updated_at
					END
				WHERE id = $1
			`
			args = []interface{}{feedID}
		}
	}

	_, err := r.pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("update telegram poll metadata: %w", err)
	}

	return nil
}

func (r *RawFeedRepository) UpdateLastExecution(ctx context.Context, feedID uuid.UUID) error {
	query := `
		UPDATE raw_feeds
		SET last_execution = NOW(),
			last_polled_at = NOW()
		WHERE id = $1
	`

	_, err := r.pool.Exec(ctx, query, feedID)
	if err != nil {
		return fmt.Errorf("update last execution: %w", err)
	}

	return nil
}

func scanRawFeeds(rows pgx.Rows) ([]domain.RawFeed, error) {
	var feeds []domain.RawFeed

	for rows.Next() {
		var feed domain.RawFeed
		var rawType string
		var pollingTier string

		err := rows.Scan(
			&feed.ID,
			&feed.Name,
			&rawType,
			&feed.FeedURL,
			&feed.SiteURL,
			&feed.ImageURL,
			&feed.TelegramChatID,
			&feed.TelegramUsername,
			&feed.LastExecution,
			&feed.LastPolledAt,
			&feed.LastMessageID,
			&feed.PollErrorCount,
			&pollingTier,
			&feed.PriorityBoostUntil,
			&feed.LastFloodWaitAt,
			&feed.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}

		feed.RawType = domain.RawFeedType(rawType)
		feed.PollingTier = domain.PollingTier(pollingTier)
		feeds = append(feeds, feed)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return feeds, nil
}

func (r *RawFeedRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.RawFeed, error) {
	query := `
		SELECT
			id, name, raw_type, feed_url, site_url, image_url,
			telegram_chat_id, telegram_username,
			last_execution, last_polled_at, last_message_id,
			poll_error_count, polling_tier, priority_boost_until, last_flood_wait_at, created_at
		FROM raw_feeds
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var feed domain.RawFeed
	var rawType string
	var pollingTier string

	err := row.Scan(
		&feed.ID,
		&feed.Name,
		&rawType,
		&feed.FeedURL,
		&feed.SiteURL,
		&feed.ImageURL,
		&feed.TelegramChatID,
		&feed.TelegramUsername,
		&feed.LastExecution,
		&feed.LastPolledAt,
		&feed.LastMessageID,
		&feed.PollErrorCount,
		&pollingTier,
		&feed.PriorityBoostUntil,
		&feed.LastFloodWaitAt,
		&feed.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("query feed: %w", err)
	}

	feed.RawType = domain.RawFeedType(rawType)
	feed.PollingTier = domain.PollingTier(pollingTier)
	return &feed, nil
}

type FeedCount struct {
	RawType string
	Count   int
}

func (r *RawFeedRepository) GetFeedCounts(ctx context.Context) ([]FeedCount, error) {
	query := `
		SELECT raw_type, COUNT(*) as count
		FROM raw_feeds
		WHERE raw_type IN ('RSS', 'WEBSITE', 'TELEGRAM')
		GROUP BY raw_type
		ORDER BY raw_type
	`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query feed counts: %w", err)
	}
	defer rows.Close()

	var counts []FeedCount
	for rows.Next() {
		var fc FeedCount
		if err := rows.Scan(&fc.RawType, &fc.Count); err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}
		counts = append(counts, fc)
	}

	return counts, nil
}

func (r *RawFeedRepository) UpdateFloodWaitAt(ctx context.Context, feedID uuid.UUID, floodWaitAt *time.Time) error {
	query := `
		UPDATE raw_feeds
		SET last_flood_wait_at = $2,
			poll_error_count = poll_error_count + 1,
			polling_tier = CASE
				WHEN poll_error_count + 1 > 5 THEN 'QUARANTINE'
				ELSE polling_tier
			END
		WHERE id = $1
	`

	_, err := r.pool.Exec(ctx, query, feedID, floodWaitAt)
	if err != nil {
		return fmt.Errorf("update flood wait at: %w", err)
	}

	return nil
}

func (r *RawFeedRepository) GetNextPollTime(ctx context.Context, feedID uuid.UUID, intervalSeconds int) (*time.Time, error) {
	feed, err := r.GetByID(ctx, feedID)
	if err != nil {
		return nil, err
	}
	if feed == nil {
		return nil, nil
	}

	if feed.LastPolledAt == nil {
		return nil, nil
	}

	nextPoll := feed.LastPolledAt.Add(time.Duration(intervalSeconds) * time.Second)
	return &nextPoll, nil
}
