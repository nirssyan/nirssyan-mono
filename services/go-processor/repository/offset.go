package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type OffsetRepository struct {
	pool *pgxpool.Pool
}

func NewOffsetRepository(pool *pgxpool.Pool) *OffsetRepository {
	return &OffsetRepository{pool: pool}
}

// GetLastProcessedRawPostID returns the last processed raw post ID for a prompt/raw_feed pair
func (r *OffsetRepository) GetLastProcessedRawPostID(ctx context.Context, promptID, rawFeedID uuid.UUID) (*uuid.UUID, error) {
	query := `
		SELECT last_processed_raw_post_id
		FROM prompts_raw_feeds_offsets
		WHERE prompt_id = $1 AND raw_feed_id = $2
	`

	var lastID *uuid.UUID
	err := r.pool.QueryRow(ctx, query, promptID, rawFeedID).Scan(&lastID)
	if err != nil {
		// If no row exists, return nil
		if err.Error() == "no rows in result set" {
			return nil, nil
		}
		return nil, fmt.Errorf("get last processed: %w", err)
	}

	return lastID, nil
}

// UpdateLastProcessedRawPostID updates or inserts the last processed raw post ID and timestamp
func (r *OffsetRepository) UpdateLastProcessedRawPostID(ctx context.Context, promptID, rawFeedID, rawPostID uuid.UUID, createdAt time.Time) error {
	query := `
		INSERT INTO prompts_raw_feeds_offsets (prompt_id, raw_feed_id, last_processed_raw_post_id, last_processed_created_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (prompt_id, raw_feed_id)
		DO UPDATE SET last_processed_raw_post_id = $3, last_processed_created_at = $4
	`

	_, err := r.pool.Exec(ctx, query, promptID, rawFeedID, rawPostID, createdAt)
	if err != nil {
		return fmt.Errorf("update last processed: %w", err)
	}

	return nil
}

// GetRawFeedIDsByPromptID returns all raw feed IDs linked to a prompt
func (r *OffsetRepository) GetRawFeedIDsByPromptID(ctx context.Context, promptID uuid.UUID) ([]uuid.UUID, error) {
	query := `
		SELECT raw_feed_id
		FROM prompts_raw_feeds
		WHERE prompt_id = $1
	`

	rows, err := r.pool.Query(ctx, query, promptID)
	if err != nil {
		return nil, fmt.Errorf("query raw feed ids: %w", err)
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan raw feed id: %w", err)
		}
		ids = append(ids, id)
	}

	return ids, rows.Err()
}
