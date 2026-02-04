package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostSeen struct {
	UserID uuid.UUID
	PostID uuid.UUID
	Seen   bool
}

type PostSeenRepository struct {
	pool *pgxpool.Pool
}

func NewPostSeenRepository(pool *pgxpool.Pool) *PostSeenRepository {
	return &PostSeenRepository{pool: pool}
}

func (r *PostSeenRepository) MarkSeen(ctx context.Context, userID uuid.UUID, postIDs []uuid.UUID) error {
	if len(postIDs) == 0 {
		return nil
	}

	query := `
		INSERT INTO posts_seen (user_id, post_id, seen)
		SELECT $1, unnest($2::uuid[]), true
		ON CONFLICT (user_id, post_id) DO UPDATE SET seen = true`

	_, err := r.pool.Exec(ctx, query, userID, postIDs)
	return err
}

func (r *PostSeenRepository) MarkAllSeenInFeed(ctx context.Context, userID, feedID uuid.UUID) (int, error) {
	query := `
		INSERT INTO posts_seen (user_id, post_id, seen)
		SELECT $1, p.id, true
		FROM posts p
		WHERE p.feed_id = $2
		  AND NOT EXISTS (
		    SELECT 1 FROM posts_seen ps
		    WHERE ps.user_id = $1 AND ps.post_id = p.id
		  )
		ON CONFLICT (user_id, post_id) DO UPDATE SET seen = true`

	result, err := r.pool.Exec(ctx, query, userID, feedID)
	if err != nil {
		return 0, err
	}
	return int(result.RowsAffected()), nil
}

func (r *PostSeenRepository) IsPostSeen(ctx context.Context, userID, postID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM posts_seen WHERE user_id = $1 AND post_id = $2)`
	var exists bool
	err := r.pool.QueryRow(ctx, query, userID, postID).Scan(&exists)
	return exists, err
}

func (r *PostSeenRepository) GetSeenMap(ctx context.Context, userID uuid.UUID, postIDs []uuid.UUID) (map[uuid.UUID]bool, error) {
	if len(postIDs) == 0 {
		return make(map[uuid.UUID]bool), nil
	}

	query := `SELECT post_id FROM posts_seen WHERE user_id = $1 AND post_id = ANY($2)`
	rows, err := r.pool.Query(ctx, query, userID, postIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[uuid.UUID]bool, len(postIDs))
	for rows.Next() {
		var postID uuid.UUID
		if err := rows.Scan(&postID); err != nil {
			return nil, err
		}
		result[postID] = true
	}
	return result, rows.Err()
}
