package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
)

type PostRepository struct {
	pool *pgxpool.Pool
}

func NewPostRepository(pool *pgxpool.Pool) *PostRepository {
	return &PostRepository{pool: pool}
}

// CreatePost creates a new post in a feed
func (r *PostRepository) CreatePost(ctx context.Context, post *domain.Post) error {
	query := `
		INSERT INTO posts (id, created_at, feed_id, image_url, title, media_objects, views,
		                   moderation_action, moderation_labels, moderation_matched_entities)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err := r.pool.Exec(ctx, query,
		post.ID, post.CreatedAt, post.FeedID, post.ImageURL, post.Title, post.MediaObjects, post.Views,
		post.ModerationAction, post.ModerationLabels, post.ModerationMatchedEntities,
	)
	if err != nil {
		return fmt.Errorf("create post: %w", err)
	}

	return nil
}

// CreatePostWithSources creates a post and its sources in a transaction
func (r *PostRepository) CreatePostWithSources(ctx context.Context, post *domain.Post, sourceURLs []string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	if len(sourceURLs) > 0 {
		var exists bool
		err := tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM sources WHERE feed_id = $1 AND source_url = $2)`,
			post.FeedID, sourceURLs[0],
		).Scan(&exists)
		if err != nil {
			return fmt.Errorf("check source exists: %w", err)
		}
		if exists {
			return nil
		}
	}

	postQuery := `
		INSERT INTO posts (id, created_at, feed_id, image_url, title, media_objects, views,
		                   moderation_action, moderation_labels, moderation_matched_entities)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err = tx.Exec(ctx, postQuery,
		post.ID, post.CreatedAt, post.FeedID, post.ImageURL, post.Title, post.MediaObjects, post.Views,
		post.ModerationAction, post.ModerationLabels, post.ModerationMatchedEntities,
	)
	if err != nil {
		return fmt.Errorf("create post: %w", err)
	}

	// Create sources (ignore duplicates since multiple posts can share the same source URL)
	for _, sourceURL := range sourceURLs {
		sourceQuery := `
			INSERT INTO sources (id, created_at, post_id, feed_id, source_url)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (feed_id, source_url) DO NOTHING
		`
		_, err = tx.Exec(ctx, sourceQuery, uuid.New(), time.Now(), post.ID, post.FeedID, sourceURL)
		if err != nil {
			return fmt.Errorf("create source: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

// GetPostsByFeedID returns posts for a feed
func (r *PostRepository) GetPostsByFeedID(ctx context.Context, feedID uuid.UUID, limit, offset int) ([]domain.Post, error) {
	query := `
		SELECT id, created_at, feed_id, image_url, title, media_objects, views,
		       moderation_action, moderation_labels, moderation_matched_entities
		FROM posts
		WHERE feed_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, feedID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("query posts: %w", err)
	}
	defer rows.Close()

	var posts []domain.Post
	for rows.Next() {
		var p domain.Post
		err := rows.Scan(
			&p.ID, &p.CreatedAt, &p.FeedID, &p.ImageURL, &p.Title, &p.MediaObjects, &p.Views,
			&p.ModerationAction, &p.ModerationLabels, &p.ModerationMatchedEntities,
		)
		if err != nil {
			return nil, fmt.Errorf("scan post: %w", err)
		}
		posts = append(posts, p)
	}

	return posts, rows.Err()
}

// UpdatePostViews updates the views JSON for a post
func (r *PostRepository) UpdatePostViews(ctx context.Context, postID uuid.UUID, views json.RawMessage) error {
	query := `UPDATE posts SET views = $2 WHERE id = $1`

	_, err := r.pool.Exec(ctx, query, postID, views)
	if err != nil {
		return fmt.Errorf("update post views: %w", err)
	}

	return nil
}

// CountPostsByFeedID returns count of posts in a feed
func (r *PostRepository) CountPostsByFeedID(ctx context.Context, feedID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM posts WHERE feed_id = $1`

	var count int
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count posts: %w", err)
	}

	return count, nil
}
