package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RawPost struct {
	ID      uuid.UUID
	Content string
	Title   *string
}

type RawPostRepository struct {
	pool *pgxpool.Pool
}

func NewRawPostRepository(pool *pgxpool.Pool) *RawPostRepository {
	return &RawPostRepository{pool: pool}
}

// GetSamplePostsByRawFeedID returns up to `limit` recent posts from a raw_feed for AI title generation
func (r *RawPostRepository) GetSamplePostsByRawFeedID(ctx context.Context, rawFeedID uuid.UUID, limit int) ([]RawPost, error) {
	query := `
		SELECT id, content, title
		FROM raw_posts
		WHERE raw_feed_id = $1 AND content IS NOT NULL AND content != ''
		ORDER BY created_at DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, query, rawFeedID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []RawPost
	for rows.Next() {
		var p RawPost
		if err := rows.Scan(&p.ID, &p.Content, &p.Title); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}

	return posts, rows.Err()
}

// GetSamplePostsByRawFeedIDs returns up to `limit` recent posts from multiple raw_feeds
func (r *RawPostRepository) GetSamplePostsByRawFeedIDs(ctx context.Context, rawFeedIDs []uuid.UUID, limit int) ([]RawPost, error) {
	if len(rawFeedIDs) == 0 {
		return nil, nil
	}

	query := `
		SELECT id, content, title
		FROM raw_posts
		WHERE raw_feed_id = ANY($1) AND content IS NOT NULL AND content != ''
		ORDER BY created_at DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, query, rawFeedIDs, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []RawPost
	for rows.Next() {
		var p RawPost
		if err := rows.Scan(&p.ID, &p.Content, &p.Title); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}

	return posts, rows.Err()
}
