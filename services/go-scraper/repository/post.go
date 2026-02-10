package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PostRow struct {
	VendorID    int
	ModelName   string
	Hash        string
	Title       string
	Description string
	Link        string
	PubDate     time.Time
	Extra       map[string]any
}

type PostRepository struct {
	pool *pgxpool.Pool
}

func NewPostRepository(pool *pgxpool.Pool) *PostRepository {
	return &PostRepository{pool: pool}
}

func (r *PostRepository) UpsertPosts(ctx context.Context, vendorID int, modelName string, posts []PostRow) (int, error) {
	if len(posts) == 0 {
		return 0, nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	inserted := 0
	for _, p := range posts {
		extraJSON, err := json.Marshal(p.Extra)
		if err != nil {
			return 0, fmt.Errorf("marshal extra: %w", err)
		}

		tag, err := tx.Exec(ctx, `
			INSERT INTO posts (vendor_id, model_name, hash, title, description, link, pub_date, extra, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
			ON CONFLICT (vendor_id, model_name, hash) DO NOTHING
		`, vendorID, modelName, p.Hash, p.Title, p.Description, p.Link, p.PubDate, extraJSON)
		if err != nil {
			return 0, fmt.Errorf("insert post: %w", err)
		}
		if tag.RowsAffected() > 0 {
			inserted++
		}
	}

	return inserted, tx.Commit(ctx)
}

func (r *PostRepository) CleanupOld(ctx context.Context, vendorID int, modelName string, keep int) error {
	_, err := r.pool.Exec(ctx, `
		DELETE FROM posts
		WHERE vendor_id = $1 AND model_name = $2
		AND id NOT IN (
			SELECT id FROM posts
			WHERE vendor_id = $1 AND model_name = $2
			ORDER BY pub_date DESC
			LIMIT $3
		)
	`, vendorID, modelName, keep)
	if err != nil {
		return fmt.Errorf("cleanup old posts: %w", err)
	}
	return nil
}
