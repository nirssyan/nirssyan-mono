package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Feed struct {
	ID                 uuid.UUID
	CreatedAt          time.Time
	Name               string
	Type               string
	Description        *string
	Tags               []string
	IsMarketplace      bool
	IsCreatingFinished bool
	ChatID             *uuid.UUID
}

type FeedWithPrompt struct {
	Feed
	PromptID       uuid.UUID
	FiltersConfig  json.RawMessage
	ViewsConfig    json.RawMessage
	Interval       *time.Duration
	LastExecution  *time.Time
	PrePromptID    *uuid.UUID
}

type FeedRepository struct {
	pool *pgxpool.Pool
}

func NewFeedRepository(pool *pgxpool.Pool) *FeedRepository {
	return &FeedRepository{pool: pool}
}

func (r *FeedRepository) GetByID(ctx context.Context, feedID uuid.UUID) (*Feed, error) {
	query := `
		SELECT id, created_at, name, type, description, tags,
		       is_marketplace, is_creating_finished, chat_id
		FROM feeds
		WHERE id = $1`

	var f Feed
	err := r.pool.QueryRow(ctx, query, feedID).Scan(
		&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
		&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *FeedRepository) GetUserFeeds(ctx context.Context, userID uuid.UUID) ([]Feed, error) {
	query := `
		SELECT f.id, f.created_at, f.name, f.type, f.description, f.tags,
		       f.is_marketplace, f.is_creating_finished, f.chat_id
		FROM feeds f
		JOIN users_feeds uf ON f.id = uf.feed_id
		WHERE uf.user_id = $1
		ORDER BY f.created_at DESC`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feeds []Feed
	for rows.Next() {
		var f Feed
		if err := rows.Scan(
			&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
			&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
		); err != nil {
			return nil, err
		}
		feeds = append(feeds, f)
	}

	return feeds, rows.Err()
}

func (r *FeedRepository) GetFeedWithPrompt(ctx context.Context, feedID uuid.UUID) (*FeedWithPrompt, error) {
	query := `
		SELECT f.id, f.created_at, f.name, f.type, f.description, f.tags,
		       f.is_marketplace, f.is_creating_finished, f.chat_id,
		       p.id as prompt_id, p.filters_config, p.views_config,
		       p.digest_interval_hours, p.last_execution, p.pre_prompt_id
		FROM feeds f
		JOIN prompts p ON p.feed_id = f.id
		WHERE f.id = $1`

	var f FeedWithPrompt
	err := r.pool.QueryRow(ctx, query, feedID).Scan(
		&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
		&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
		&f.PromptID, &f.FiltersConfig, &f.ViewsConfig,
		&f.Interval, &f.LastExecution, &f.PrePromptID,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *FeedRepository) CountRawFeedsByFeedID(ctx context.Context, feedID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM prompts_raw_feeds prf
	          JOIN prompts p ON prf.prompt_id = p.id
	          WHERE p.feed_id = $1`
	var count int
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&count)
	return count, err
}

type CreateFeedParams struct {
	ID          uuid.UUID
	Name        string
	Type        string
	Description *string
	Tags        []string
	ChatID      *uuid.UUID
}

func (r *FeedRepository) Create(ctx context.Context, params CreateFeedParams) (*Feed, error) {
	query := `
		INSERT INTO feeds (id, name, type, description, tags, chat_id, is_creating_finished)
		VALUES ($1, $2, $3, $4, $5, $6, false)
		RETURNING id, created_at, name, type, description, tags,
		          is_marketplace, is_creating_finished, chat_id`

	var f Feed
	err := r.pool.QueryRow(ctx, query,
		params.ID, params.Name, params.Type, params.Description,
		params.Tags, params.ChatID,
	).Scan(
		&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
		&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
	)
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *FeedRepository) UpdateName(ctx context.Context, feedID uuid.UUID, name string) error {
	query := `UPDATE feeds SET name = $2 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, feedID, name)
	return err
}

func (r *FeedRepository) MarkCreatingFinished(ctx context.Context, feedID uuid.UUID) error {
	query := `UPDATE feeds SET is_creating_finished = true WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, feedID)
	return err
}

func (r *FeedRepository) Delete(ctx context.Context, feedID uuid.UUID) error {
	query := `DELETE FROM feeds WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, feedID)
	return err
}

func (r *FeedRepository) UserHasAccess(ctx context.Context, userID, feedID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM users_feeds WHERE user_id = $1 AND feed_id = $2)`
	var exists bool
	err := r.pool.QueryRow(ctx, query, userID, feedID).Scan(&exists)
	return exists, err
}

type UpdateFeedParams struct {
	Name        *string
	Description *string
	Tags        []string
}

func (r *FeedRepository) Update(ctx context.Context, feedID uuid.UUID, params UpdateFeedParams) (*Feed, error) {
	updates := []string{}
	args := []interface{}{}
	argIndex := 1

	if params.Name != nil {
		updates = append(updates, fmt.Sprintf("name = $%d", argIndex))
		args = append(args, *params.Name)
		argIndex++
	}

	if params.Description != nil {
		updates = append(updates, fmt.Sprintf("description = $%d", argIndex))
		args = append(args, *params.Description)
		argIndex++
	}

	if params.Tags != nil {
		updates = append(updates, fmt.Sprintf("tags = $%d", argIndex))
		args = append(args, params.Tags)
		argIndex++
	}

	if len(updates) == 0 {
		return r.GetByID(ctx, feedID)
	}

	args = append(args, feedID)
	query := fmt.Sprintf(`
		UPDATE feeds
		SET %s
		WHERE id = $%d
		RETURNING id, created_at, name, type, description, tags,
		          is_marketplace, is_creating_finished, chat_id`,
		strings.Join(updates, ", "), argIndex)

	var f Feed
	err := r.pool.QueryRow(ctx, query, args...).Scan(
		&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
		&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &f, nil
}
