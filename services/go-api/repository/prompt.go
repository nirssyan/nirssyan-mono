package repository

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Prompt struct {
	ID                  uuid.UUID
	FeedID              uuid.UUID
	FeedType            string
	ViewsConfig         json.RawMessage
	FiltersConfig       json.RawMessage
	PrePromptID         *uuid.UUID
	DigestIntervalHours *int
	LastExecution       *time.Time
	CreatedAt           time.Time
}

type PromptRepository struct {
	pool *pgxpool.Pool
}

func NewPromptRepository(pool *pgxpool.Pool) *PromptRepository {
	return &PromptRepository{pool: pool}
}

type CreatePromptParams struct {
	ID                  uuid.UUID
	FeedID              uuid.UUID
	FeedType            string
	ViewsConfig         json.RawMessage
	FiltersConfig       json.RawMessage
	PrePromptID         *uuid.UUID
	DigestIntervalHours *int
}

func (r *PromptRepository) Create(ctx context.Context, params CreatePromptParams) (*Prompt, error) {
	query := `
		INSERT INTO prompts (id, feed_id, feed_type, views_config, filters_config, pre_prompt_id, digest_interval_hours, prompt)
		VALUES ($1, $2, $3, $4, $5, $6, $7, '{}')
		RETURNING id, feed_id, feed_type, views_config, filters_config, pre_prompt_id, digest_interval_hours, last_execution, created_at`

	var p Prompt
	err := r.pool.QueryRow(ctx, query,
		params.ID, params.FeedID, params.FeedType, params.ViewsConfig,
		params.FiltersConfig, params.PrePromptID, params.DigestIntervalHours,
	).Scan(
		&p.ID, &p.FeedID, &p.FeedType, &p.ViewsConfig, &p.FiltersConfig,
		&p.PrePromptID, &p.DigestIntervalHours, &p.LastExecution, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *PromptRepository) GetByFeedID(ctx context.Context, feedID uuid.UUID) (*Prompt, error) {
	query := `
		SELECT id, feed_id, feed_type, views_config, filters_config, pre_prompt_id,
		       digest_interval_hours, last_execution, created_at
		FROM prompts
		WHERE feed_id = $1`

	var p Prompt
	err := r.pool.QueryRow(ctx, query, feedID).Scan(
		&p.ID, &p.FeedID, &p.FeedType, &p.ViewsConfig, &p.FiltersConfig,
		&p.PrePromptID, &p.DigestIntervalHours, &p.LastExecution, &p.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

type UpdatePromptParams struct {
	RawPrompt           *string
	ViewsRaw            []string
	FiltersRaw          []string
	DigestIntervalHours *int
}

func (r *PromptRepository) Update(ctx context.Context, promptID uuid.UUID, params UpdatePromptParams) error {
	if params.DigestIntervalHours != nil {
		_, err := r.pool.Exec(ctx,
			`UPDATE prompts SET digest_interval_hours = $2 WHERE id = $1`,
			promptID, *params.DigestIntervalHours)
		if err != nil {
			return err
		}
	}
	if len(params.ViewsRaw) > 0 {
		viewsJSON, _ := json.Marshal(params.ViewsRaw)
		_, err := r.pool.Exec(ctx,
			`UPDATE prompts SET views_config = $2 WHERE id = $1`,
			promptID, viewsJSON)
		if err != nil {
			return err
		}
	}
	if len(params.FiltersRaw) > 0 {
		filtersJSON, _ := json.Marshal(params.FiltersRaw)
		_, err := r.pool.Exec(ctx,
			`UPDATE prompts SET filters_config = $2 WHERE id = $1`,
			promptID, filtersJSON)
		if err != nil {
			return err
		}
	}
	if params.RawPrompt != nil {
		_, err := r.pool.Exec(ctx,
			`UPDATE prompts SET prompt = $2 WHERE id = $1`,
			promptID, *params.RawPrompt)
		if err != nil {
			return err
		}
	}
	return nil
}
