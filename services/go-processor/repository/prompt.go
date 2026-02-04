package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
)

type PromptRepository struct {
	pool *pgxpool.Pool
}

func NewPromptRepository(pool *pgxpool.Pool) *PromptRepository {
	return &PromptRepository{pool: pool}
}

// GetPromptsByRawFeedID returns all prompts linked to a raw feed
func (r *PromptRepository) GetPromptsByRawFeedID(ctx context.Context, rawFeedID uuid.UUID) ([]domain.Prompt, error) {
	query := `
		SELECT p.id, p.feed_id, p.feed_type, p.views_config, p.filters_config,
		       p.pre_prompt_id, p.digest_interval_hours, p.last_execution
		FROM prompts p
		JOIN prompts_raw_feeds prf ON p.id = prf.prompt_id
		WHERE prf.raw_feed_id = $1
	`

	rows, err := r.pool.Query(ctx, query, rawFeedID)
	if err != nil {
		return nil, fmt.Errorf("query prompts by raw feed: %w", err)
	}
	defer rows.Close()

	return scanPrompts(rows)
}

// GetPromptByID returns a prompt by its ID
func (r *PromptRepository) GetPromptByID(ctx context.Context, promptID uuid.UUID) (*domain.Prompt, error) {
	query := `
		SELECT id, feed_id, feed_type, views_config, filters_config,
		       pre_prompt_id, digest_interval_hours, last_execution
		FROM prompts
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, promptID)
	return scanPrompt(row)
}

// GetPromptByFeedID returns prompt for a feed
func (r *PromptRepository) GetPromptByFeedID(ctx context.Context, feedID uuid.UUID) (*domain.Prompt, error) {
	query := `
		SELECT id, feed_id, feed_type, views_config, filters_config,
		       pre_prompt_id, digest_interval_hours, last_execution
		FROM prompts
		WHERE feed_id = $1
	`

	row := r.pool.QueryRow(ctx, query, feedID)
	return scanPrompt(row)
}

// UpdateLastExecution updates the last execution time
func (r *PromptRepository) UpdateLastExecution(ctx context.Context, promptID uuid.UUID) error {
	query := `UPDATE prompts SET last_execution = NOW() WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, promptID)
	if err != nil {
		return fmt.Errorf("update last execution: %w", err)
	}
	return nil
}

// UpdateViewsConfig updates the views configuration
func (r *PromptRepository) UpdateViewsConfig(ctx context.Context, promptID uuid.UUID, viewsConfig json.RawMessage) error {
	query := `UPDATE prompts SET views_config = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, promptID, viewsConfig)
	if err != nil {
		return fmt.Errorf("update views config: %w", err)
	}
	return nil
}

// UpdateFiltersConfig updates the filters configuration
func (r *PromptRepository) UpdateFiltersConfig(ctx context.Context, promptID uuid.UUID, filtersConfig json.RawMessage) error {
	query := `UPDATE prompts SET filters_config = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, promptID, filtersConfig)
	if err != nil {
		return fmt.Errorf("update filters config: %w", err)
	}
	return nil
}

func scanPrompts(rows pgx.Rows) ([]domain.Prompt, error) {
	var prompts []domain.Prompt

	for rows.Next() {
		var p domain.Prompt
		err := rows.Scan(
			&p.ID, &p.FeedID, &p.FeedType, &p.ViewsConfig, &p.FiltersConfig,
			&p.PrePromptID, &p.Interval, &p.LastExecution,
		)
		if err != nil {
			return nil, fmt.Errorf("scan prompt: %w", err)
		}
		prompts = append(prompts, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return prompts, nil
}

func scanPrompt(row pgx.Row) (*domain.Prompt, error) {
	var p domain.Prompt
	err := row.Scan(
		&p.ID, &p.FeedID, &p.FeedType, &p.ViewsConfig, &p.FiltersConfig,
		&p.PrePromptID, &p.Interval, &p.LastExecution,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("scan prompt: %w", err)
	}
	return &p, nil
}
