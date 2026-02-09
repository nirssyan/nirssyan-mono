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
	Message   *string
	ImageURLs []string
	CreatedAt time.Time
}

type FeedbackRepository struct {
	pool *pgxpool.Pool
}

func NewFeedbackRepository(pool *pgxpool.Pool) *FeedbackRepository {
	return &FeedbackRepository{pool: pool}
}

type CreateFeedbackParams struct {
	UserID    uuid.UUID
	Message   *string
	ImageURLs []string
}

func (r *FeedbackRepository) Create(ctx context.Context, params CreateFeedbackParams) (*Feedback, error) {
	query := `
		INSERT INTO feedbacks (user_id, message, image_urls)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, message, image_urls, created_at`

	var f Feedback
	err := r.pool.QueryRow(ctx, query,
		params.UserID, params.Message, params.ImageURLs,
	).Scan(&f.ID, &f.UserID, &f.Message, &f.ImageURLs, &f.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &f, nil
}
