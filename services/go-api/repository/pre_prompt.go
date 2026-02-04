package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PrePrompt struct {
	ID                  uuid.UUID
	Type                string
	Prompt              *string
	Sources             []string
	ViewsRaw            []string
	FiltersRaw          []string
	DigestIntervalHours *int
	CreatedAt           time.Time
}

type PrePromptRepository struct {
	pool *pgxpool.Pool
}

func NewPrePromptRepository(pool *pgxpool.Pool) *PrePromptRepository {
	return &PrePromptRepository{pool: pool}
}

type CreatePrePromptParams struct {
	Type                string
	Prompt              *string
	Sources             []string
	ViewsRaw            []string
	FiltersRaw          []string
	DigestIntervalHours *int
}

func (r *PrePromptRepository) Create(ctx context.Context, params CreatePrePromptParams) (*PrePrompt, error) {
	query := `
		INSERT INTO pre_prompts (type, prompt, sources, views_raw, filters_raw, digest_interval_hours)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, type, prompt, sources, views_raw, filters_raw, digest_interval_hours, created_at`

	var pp PrePrompt

	err := r.pool.QueryRow(ctx, query,
		params.Type, params.Prompt, params.Sources, params.ViewsRaw, params.FiltersRaw, params.DigestIntervalHours,
	).Scan(
		&pp.ID, &pp.Type, &pp.Prompt, &pp.Sources, &pp.ViewsRaw, &pp.FiltersRaw, &pp.DigestIntervalHours, &pp.CreatedAt,
	)
	if err != nil {
		return nil, err
	}

	return &pp, nil
}

func (r *PrePromptRepository) GetByID(ctx context.Context, id uuid.UUID) (*PrePrompt, error) {
	query := `
		SELECT id, type, prompt, sources, views_raw, filters_raw, digest_interval_hours, created_at
		FROM pre_prompts
		WHERE id = $1`

	var pp PrePrompt

	err := r.pool.QueryRow(ctx, query, id).Scan(
		&pp.ID, &pp.Type, &pp.Prompt, &pp.Sources, &pp.ViewsRaw, &pp.FiltersRaw, &pp.DigestIntervalHours, &pp.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &pp, nil
}
