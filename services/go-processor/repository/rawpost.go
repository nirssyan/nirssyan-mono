package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
)

type RawPostRepository struct {
	pool *pgxpool.Pool
}

func NewRawPostRepository(pool *pgxpool.Pool) *RawPostRepository {
	return &RawPostRepository{pool: pool}
}

// GetByIDs returns raw posts by their IDs
func (r *RawPostRepository) GetByIDs(ctx context.Context, ids []uuid.UUID) ([]domain.RawPost, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	query := `
		SELECT id, created_at, content, raw_feed_id, rp_unique_code,
		       title, media_group_id, telegram_message_id, media_objects, source_url,
		       moderation_action, moderation_labels, moderation_block_reasons,
		       moderation_checked_at, moderation_matched_entities
		FROM raw_posts
		WHERE id = ANY($1)
		ORDER BY created_at ASC
	`

	rows, err := r.pool.Query(ctx, query, ids)
	if err != nil {
		return nil, fmt.Errorf("query raw posts by ids: %w", err)
	}
	defer rows.Close()

	return scanRawPosts(rows)
}

// GetUnprocessedByPromptAndRawFeed returns raw posts that haven't been processed for a prompt
func (r *RawPostRepository) GetUnprocessedByPromptAndRawFeed(ctx context.Context, promptID, rawFeedID uuid.UUID, limit int) ([]domain.RawPost, error) {
	query := `
		SELECT rp.id, rp.created_at, rp.content, rp.raw_feed_id, rp.rp_unique_code,
		       rp.title, rp.media_group_id, rp.telegram_message_id, rp.media_objects, rp.source_url,
		       rp.moderation_action, rp.moderation_labels, rp.moderation_block_reasons,
		       rp.moderation_checked_at, rp.moderation_matched_entities
		FROM raw_posts rp
		LEFT JOIN prompts_raw_feeds_offsets prfo
		    ON prfo.prompt_id = $1 AND prfo.raw_feed_id = $2
		WHERE rp.raw_feed_id = $2
		  AND (prfo.last_processed_raw_post_id IS NULL
		       OR rp.id > prfo.last_processed_raw_post_id)
		ORDER BY rp.created_at ASC
		LIMIT $3
	`

	rows, err := r.pool.Query(ctx, query, promptID, rawFeedID, limit)
	if err != nil {
		return nil, fmt.Errorf("query unprocessed raw posts: %w", err)
	}
	defer rows.Close()

	return scanRawPosts(rows)
}

// GetRecentByRawFeed returns recent raw posts for a raw feed
func (r *RawPostRepository) GetRecentByRawFeed(ctx context.Context, rawFeedID uuid.UUID, since time.Time, limit int) ([]domain.RawPost, error) {
	query := `
		SELECT id, created_at, content, raw_feed_id, rp_unique_code,
		       title, media_group_id, telegram_message_id, media_objects, source_url,
		       moderation_action, moderation_labels, moderation_block_reasons,
		       moderation_checked_at, moderation_matched_entities
		FROM raw_posts
		WHERE raw_feed_id = $1
		  AND created_at >= $2
		ORDER BY created_at DESC
		LIMIT $3
	`

	rows, err := r.pool.Query(ctx, query, rawFeedID, since, limit)
	if err != nil {
		return nil, fmt.Errorf("query recent raw posts: %w", err)
	}
	defer rows.Close()

	return scanRawPosts(rows)
}

// GetLatestByRawFeed returns the latest raw posts for a raw feed regardless of date
func (r *RawPostRepository) GetLatestByRawFeed(ctx context.Context, rawFeedID uuid.UUID, limit int) ([]domain.RawPost, error) {
	query := `
		SELECT id, created_at, content, raw_feed_id, rp_unique_code,
		       title, media_group_id, telegram_message_id, media_objects, source_url,
		       moderation_action, moderation_labels, moderation_block_reasons,
		       moderation_checked_at, moderation_matched_entities
		FROM raw_posts
		WHERE raw_feed_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`

	rows, err := r.pool.Query(ctx, query, rawFeedID, limit)
	if err != nil {
		return nil, fmt.Errorf("query latest raw posts: %w", err)
	}
	defer rows.Close()

	return scanRawPosts(rows)
}

// GetContentByIDs returns just the content of raw posts (for AI processing)
func (r *RawPostRepository) GetContentByIDs(ctx context.Context, ids []uuid.UUID) ([]string, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	query := `SELECT content FROM raw_posts WHERE id = ANY($1) ORDER BY created_at ASC`

	rows, err := r.pool.Query(ctx, query, ids)
	if err != nil {
		return nil, fmt.Errorf("query raw post content: %w", err)
	}
	defer rows.Close()

	var contents []string
	for rows.Next() {
		var content string
		if err := rows.Scan(&content); err != nil {
			return nil, fmt.Errorf("scan content: %w", err)
		}
		contents = append(contents, content)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return contents, nil
}

func scanRawPosts(rows pgx.Rows) ([]domain.RawPost, error) {
	var posts []domain.RawPost

	for rows.Next() {
		var p domain.RawPost
		err := rows.Scan(
			&p.ID, &p.CreatedAt, &p.Content, &p.RawFeedID, &p.RPUniqueCode,
			&p.Title, &p.MediaGroupID, &p.TelegramMessageID, &p.MediaObjects, &p.SourceURL,
			&p.ModerationAction, &p.ModerationLabels, &p.ModerationBlockReasons,
			&p.ModerationCheckedAt, &p.ModerationMatchedEntities,
		)
		if err != nil {
			return nil, fmt.Errorf("scan raw post: %w", err)
		}
		posts = append(posts, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return posts, nil
}
