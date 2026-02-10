package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Post struct {
	Title       string    `json:"title"`
	Link        string    `json:"link"`
	Description string    `json:"description"`
	PubDate     time.Time `json:"pub_date"`
	Hash        string    `json:"hash"`
}

type PostRepository struct {
	pool *pgxpool.Pool
}

func NewPostRepository(pool *pgxpool.Pool) *PostRepository {
	return &PostRepository{pool: pool}
}

func (r *PostRepository) GetLatest(ctx context.Context, vendorID int, modelName string, limit int) ([]Post, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT title, link, description, pub_date, hash FROM posts
		 WHERE vendor_id = $1 AND model_name = $2
		 ORDER BY pub_date DESC LIMIT $3`,
		vendorID, modelName, limit)
	if err != nil {
		return nil, fmt.Errorf("query posts: %w", err)
	}
	defer rows.Close()

	var posts []Post
	for rows.Next() {
		var p Post
		if err := rows.Scan(&p.Title, &p.Link, &p.Description, &p.PubDate, &p.Hash); err != nil {
			return nil, fmt.Errorf("scan post: %w", err)
		}
		posts = append(posts, p)
	}
	return posts, rows.Err()
}
