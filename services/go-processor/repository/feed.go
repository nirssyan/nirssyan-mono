package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
)

type FeedRepository struct {
	pool *pgxpool.Pool
}

func NewFeedRepository(pool *pgxpool.Pool) *FeedRepository {
	return &FeedRepository{pool: pool}
}

// GetByID returns a feed by ID
func (r *FeedRepository) GetByID(ctx context.Context, feedID uuid.UUID) (*domain.Feed, error) {
	query := `
		SELECT id, created_at, name, type, description, tags, is_marketplace, is_creating_finished, chat_id
		FROM feeds
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, feedID)

	var f domain.Feed
	err := row.Scan(
		&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
		&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("scan feed: %w", err)
	}

	return &f, nil
}

// UpdateName updates the feed name
func (r *FeedRepository) UpdateName(ctx context.Context, feedID uuid.UUID, name string) error {
	query := `UPDATE feeds SET name = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, feedID, name)
	if err != nil {
		return fmt.Errorf("update feed name: %w", err)
	}

	return nil
}

// UpdateDescription updates the feed description
func (r *FeedRepository) UpdateDescription(ctx context.Context, feedID uuid.UUID, description string) error {
	query := `UPDATE feeds SET description = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, feedID, description)
	if err != nil {
		return fmt.Errorf("update feed description: %w", err)
	}

	return nil
}

// UpdateTags updates the feed tags
func (r *FeedRepository) UpdateTags(ctx context.Context, feedID uuid.UUID, tags []string) error {
	query := `UPDATE feeds SET tags = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, feedID, tags)
	if err != nil {
		return fmt.Errorf("update feed tags: %w", err)
	}

	return nil
}

// MarkCreatingFinished sets is_creating_finished to true
func (r *FeedRepository) MarkCreatingFinished(ctx context.Context, feedID uuid.UUID) error {
	query := `UPDATE feeds SET is_creating_finished = true WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, feedID)
	if err != nil {
		return fmt.Errorf("mark creating finished: %w", err)
	}

	return nil
}

// GetFeedOwnerID returns the user_id of the feed owner from users_feeds table
func (r *FeedRepository) GetFeedOwnerID(ctx context.Context, feedID uuid.UUID) (uuid.UUID, error) {
	query := `SELECT user_id FROM users_feeds WHERE feed_id = $1 LIMIT 1`

	var userID uuid.UUID
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return uuid.Nil, nil
		}
		return uuid.Nil, fmt.Errorf("get feed owner: %w", err)
	}

	return userID, nil
}
