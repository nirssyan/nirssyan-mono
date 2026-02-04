package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
)

type RawPostRepository struct {
	pool *pgxpool.Pool
}

func NewRawPostRepository(pool *pgxpool.Pool) *RawPostRepository {
	return &RawPostRepository{pool: pool}
}

func (r *RawPostRepository) BatchCheckExists(ctx context.Context, uniqueCodes []string) (map[string]bool, error) {
	if len(uniqueCodes) == 0 {
		return make(map[string]bool), nil
	}

	query := `
		SELECT rp_unique_code
		FROM raw_posts
		WHERE rp_unique_code = ANY($1)
	`

	rows, err := r.pool.Query(ctx, query, uniqueCodes)
	if err != nil {
		return nil, fmt.Errorf("query existing codes: %w", err)
	}
	defer rows.Close()

	existing := make(map[string]bool)
	for rows.Next() {
		var code string
		if err := rows.Scan(&code); err != nil {
			return nil, fmt.Errorf("scan code: %w", err)
		}
		existing[code] = true
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return existing, nil
}

func (r *RawPostRepository) BatchCreate(ctx context.Context, posts []domain.RawPostCreateData) ([]uuid.UUID, error) {
	if len(posts) == 0 {
		return nil, nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	ids := make([]uuid.UUID, 0, len(posts))

	for _, post := range posts {
		id, err := r.createSingle(ctx, tx, post)
		if err != nil {
			return nil, fmt.Errorf("create post: %w", err)
		}
		ids = append(ids, id)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit transaction: %w", err)
	}

	return ids, nil
}

func (r *RawPostRepository) createSingle(ctx context.Context, tx pgx.Tx, post domain.RawPostCreateData) (uuid.UUID, error) {
	mediaObjectsJSON, err := json.Marshal(post.MediaObjects)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal media objects: %w", err)
	}

	labelsJSON, err := json.Marshal(post.ModerationLabels)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal labels: %w", err)
	}

	blockReasonsJSON, err := json.Marshal(post.ModerationBlockReasons)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal block reasons: %w", err)
	}

	query := `
		INSERT INTO raw_posts (
			content, raw_feed_id, media_objects, rp_unique_code, title,
			media_group_id, telegram_message_id, source_url, created_at,
			moderation_action, moderation_labels, moderation_block_reasons, moderation_checked_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, COALESCE($9, NOW()), $10, $11, $12, $13)
		RETURNING id
	`

	var id uuid.UUID
	err = tx.QueryRow(ctx, query,
		post.Content,
		post.RawFeedID,
		mediaObjectsJSON,
		post.RPUniqueCode,
		post.Title,
		post.MediaGroupID,
		post.TelegramMessageID,
		post.SourceURL,
		post.CreatedAt,
		string(post.ModerationAction),
		labelsJSON,
		blockReasonsJSON,
		post.ModerationCheckedAt,
	).Scan(&id)

	if err != nil {
		return uuid.Nil, fmt.Errorf("insert raw post: %w", err)
	}

	return id, nil
}

func (r *RawPostRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.RawPost, error) {
	query := `
		SELECT
			id, content, raw_feed_id, media_objects, rp_unique_code, title,
			media_group_id, telegram_message_id, source_url, created_at,
			moderation_action, moderation_labels, moderation_block_reasons, moderation_checked_at
		FROM raw_posts
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var post domain.RawPost
	var mediaObjectsJSON []byte
	var labelsJSON []byte
	var blockReasonsJSON []byte
	var moderationAction string

	err := row.Scan(
		&post.ID,
		&post.Content,
		&post.RawFeedID,
		&mediaObjectsJSON,
		&post.RPUniqueCode,
		&post.Title,
		&post.MediaGroupID,
		&post.TelegramMessageID,
		&post.SourceURL,
		&post.CreatedAt,
		&moderationAction,
		&labelsJSON,
		&blockReasonsJSON,
		&post.ModerationCheckedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("query post: %w", err)
	}

	if err := json.Unmarshal(mediaObjectsJSON, &post.MediaObjects); err != nil {
		return nil, fmt.Errorf("unmarshal media objects: %w", err)
	}

	if err := json.Unmarshal(labelsJSON, &post.ModerationLabels); err != nil {
		return nil, fmt.Errorf("unmarshal labels: %w", err)
	}

	if err := json.Unmarshal(blockReasonsJSON, &post.ModerationBlockReasons); err != nil {
		return nil, fmt.Errorf("unmarshal block reasons: %w", err)
	}

	post.ModerationAction = domain.ModerationAction(moderationAction)

	return &post, nil
}

func (r *RawPostRepository) CountByFeed(ctx context.Context, feedID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM raw_posts WHERE raw_feed_id = $1`

	var count int
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count posts: %w", err)
	}

	return count, nil
}
