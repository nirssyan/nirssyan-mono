package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
)

// LLMModel represents an LLM model in the database
type LLMModel struct {
	ID              uuid.UUID       `json:"id"`
	ModelID         string          `json:"model_id"`
	Name            string          `json:"name"`
	ContextLength   int             `json:"context_length"`
	PricePrompt     decimal.Decimal `json:"price_prompt"`
	PriceCompletion decimal.Decimal `json:"price_completion"`
	ModelCreatedAt  *int64          `json:"model_created_at"`
	PricesChangedAt *time.Time      `json:"prices_changed_at"`
	LastSyncedAt    *time.Time      `json:"last_synced_at"`
	CreatedAt       time.Time       `json:"created_at"`
}

type LLMModelsRepository struct {
	pool *pgxpool.Pool
}

func NewLLMModelsRepository(pool *pgxpool.Pool) *LLMModelsRepository {
	return &LLMModelsRepository{pool: pool}
}

// GetAllModelIDs returns all model IDs in the database
func (r *LLMModelsRepository) GetAllModelIDs(ctx context.Context) (map[string]struct{}, error) {
	query := `SELECT model_id FROM llm_models`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query model ids: %w", err)
	}
	defer rows.Close()

	result := make(map[string]struct{})
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan model id: %w", err)
		}
		result[id] = struct{}{}
	}

	return result, rows.Err()
}

// GetModelByID returns a model by its model_id
func (r *LLMModelsRepository) GetModelByID(ctx context.Context, modelID string) (*LLMModel, error) {
	query := `
		SELECT id, model_id, name, context_length,
		       price_prompt, price_completion, model_created_at,
		       prices_changed_at, last_synced_at, created_at
		FROM llm_models
		WHERE model_id = $1
	`

	row := r.pool.QueryRow(ctx, query, modelID)

	var m LLMModel
	err := row.Scan(
		&m.ID, &m.ModelID, &m.Name, &m.ContextLength,
		&m.PricePrompt, &m.PriceCompletion, &m.ModelCreatedAt,
		&m.PricesChangedAt, &m.LastSyncedAt, &m.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("scan model: %w", err)
	}

	return &m, nil
}

// InsertModel inserts a new model
func (r *LLMModelsRepository) InsertModel(ctx context.Context, model *LLMModel) error {
	query := `
		INSERT INTO llm_models (id, model_id, name, context_length,
		                        price_prompt, price_completion, model_created_at, last_synced_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	if model.ID == uuid.Nil {
		model.ID = uuid.New()
	}
	if model.CreatedAt.IsZero() {
		model.CreatedAt = time.Now()
	}

	now := time.Now()
	_, err := r.pool.Exec(ctx, query,
		model.ID, model.ModelID, model.Name, model.ContextLength,
		model.PricePrompt, model.PriceCompletion, model.ModelCreatedAt, now, model.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("insert model: %w", err)
	}

	return nil
}

// UpdateModelPrices updates prices and records change to history
func (r *LLMModelsRepository) UpdateModelPrices(ctx context.Context, modelID uuid.UUID, modelIDStr string, oldPrompt, oldCompletion, newPrompt, newCompletion decimal.Decimal) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Record price change
	historyQuery := `
		INSERT INTO llm_model_price_history (id, llm_model_uuid, model_id,
		                                     prev_price_prompt, prev_price_completion,
		                                     new_price_prompt, new_price_completion, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	now := time.Now()
	_, err = tx.Exec(ctx, historyQuery,
		uuid.New(), modelID, modelIDStr,
		oldPrompt, oldCompletion,
		newPrompt, newCompletion, now,
	)
	if err != nil {
		return fmt.Errorf("insert price history: %w", err)
	}

	// Update model prices
	updateQuery := `
		UPDATE llm_models
		SET price_prompt = $2, price_completion = $3,
		    prices_changed_at = $4, last_synced_at = $4
		WHERE id = $1
	`

	_, err = tx.Exec(ctx, updateQuery, modelID, newPrompt, newCompletion, now)
	if err != nil {
		return fmt.Errorf("update model prices: %w", err)
	}

	return tx.Commit(ctx)
}

// UpdateLastSyncedAt updates the last_synced_at timestamp
func (r *LLMModelsRepository) UpdateLastSyncedAt(ctx context.Context, modelID string) error {
	query := `UPDATE llm_models SET last_synced_at = $2 WHERE model_id = $1`

	_, err := r.pool.Exec(ctx, query, modelID, time.Now())
	if err != nil {
		return fmt.Errorf("update last synced: %w", err)
	}

	return nil
}
