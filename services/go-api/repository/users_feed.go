package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserFeed struct {
	UserID    uuid.UUID
	FeedID    uuid.UUID
	CreatedAt time.Time
}

type UsersFeedRepository struct {
	pool *pgxpool.Pool
}

func NewUsersFeedRepository(pool *pgxpool.Pool) *UsersFeedRepository {
	return &UsersFeedRepository{pool: pool}
}

func (r *UsersFeedRepository) Subscribe(ctx context.Context, userID, feedID uuid.UUID) error {
	query := `
		INSERT INTO users_feeds (user_id, feed_id)
		VALUES ($1, $2)
		ON CONFLICT (user_id, feed_id) DO NOTHING`

	_, err := r.pool.Exec(ctx, query, userID, feedID)
	return err
}

func (r *UsersFeedRepository) Unsubscribe(ctx context.Context, userID, feedID uuid.UUID) error {
	query := `DELETE FROM users_feeds WHERE user_id = $1 AND feed_id = $2`
	_, err := r.pool.Exec(ctx, query, userID, feedID)
	return err
}

func (r *UsersFeedRepository) IsSubscribed(ctx context.Context, userID, feedID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM users_feeds WHERE user_id = $1 AND feed_id = $2)`
	var exists bool
	err := r.pool.QueryRow(ctx, query, userID, feedID).Scan(&exists)
	return exists, err
}

func (r *UsersFeedRepository) CountUserFeeds(ctx context.Context, userID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM users_feeds WHERE user_id = $1`
	var count int
	err := r.pool.QueryRow(ctx, query, userID).Scan(&count)
	return count, err
}

func (r *UsersFeedRepository) Create(ctx context.Context, userID, feedID uuid.UUID) error {
	return r.Subscribe(ctx, userID, feedID)
}

func (r *UsersFeedRepository) CountFeedSubscribers(ctx context.Context, feedID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM users_feeds WHERE feed_id = $1`
	var count int
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&count)
	return count, err
}
