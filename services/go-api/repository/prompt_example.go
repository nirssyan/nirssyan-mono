package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PromptExample struct {
	ID        uuid.UUID
	Prompt    string
	Tags      []string
	CreatedAt time.Time
}

type PromptExampleRepository struct {
	pool *pgxpool.Pool
}

func NewPromptExampleRepository(pool *pgxpool.Pool) *PromptExampleRepository {
	return &PromptExampleRepository{pool: pool}
}

func (r *PromptExampleRepository) GetByUserTags(ctx context.Context, userID uuid.UUID) ([]PromptExample, error) {
	query := `
		SELECT DISTINCT pe.id, pe.prompt, pe.created_at,
			COALESCE(array_agg(DISTINCT t.name) FILTER (WHERE t.name IS NOT NULL), '{}') as tags
		FROM prompt_examples pe
		JOIN prompt_examples_tags pet ON pet.prompt_example_id = pe.id
		JOIN tags t ON t.id = pet.tag_id
		WHERE pet.tag_id IN (SELECT tag_id FROM users_tags WHERE user_id = $1)
		GROUP BY pe.id, pe.prompt, pe.created_at
		ORDER BY pe.created_at DESC`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var examples []PromptExample
	for rows.Next() {
		var pe PromptExample
		if err := rows.Scan(&pe.ID, &pe.Prompt, &pe.CreatedAt, &pe.Tags); err != nil {
			return nil, err
		}
		examples = append(examples, pe)
	}

	return examples, rows.Err()
}
