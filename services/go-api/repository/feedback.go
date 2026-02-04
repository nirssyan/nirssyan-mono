package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Feedback struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Message   string
	Type      string
	Metadata  *string
	CreatedAt time.Time
}

type FeedbackRepository struct {
	pool *pgxpool.Pool
}

func NewFeedbackRepository(pool *pgxpool.Pool) *FeedbackRepository {
	return &FeedbackRepository{pool: pool}
}

type CreateFeedbackParams struct {
	UserID   uuid.UUID
	Message  string
	Type     string
	Metadata *string
}

func (r *FeedbackRepository) Create(ctx context.Context, params CreateFeedbackParams) (*Feedback, error) {
	query := `
		INSERT INTO feedbacks (user_id, message, type, metadata)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, message, type, metadata, created_at`

	var f Feedback
	err := r.pool.QueryRow(ctx, query,
		params.UserID, params.Message, params.Type, params.Metadata,
	).Scan(&f.ID, &f.UserID, &f.Message, &f.Type, &f.Metadata, &f.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &f, nil
}
