package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type SubscriptionRow struct {
	ID        string
	VendorID  int
	ModelName string
	Slug      string
	IsActive  bool
	LastScrapedAt *time.Time
}

type SubscriptionRepository struct {
	pool *pgxpool.Pool
}

func NewSubscriptionRepository(pool *pgxpool.Pool) *SubscriptionRepository {
	return &SubscriptionRepository{pool: pool}
}

func (r *SubscriptionRepository) GetActive(ctx context.Context) ([]SubscriptionRow, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, vendor_id, model_name, slug, last_scraped_at
		FROM subscriptions
		WHERE is_active = true
		ORDER BY last_scraped_at ASC NULLS FIRST
	`)
	if err != nil {
		return nil, fmt.Errorf("query active subscriptions: %w", err)
	}
	defer rows.Close()

	var subs []SubscriptionRow
	for rows.Next() {
		var s SubscriptionRow
		if err := rows.Scan(&s.ID, &s.VendorID, &s.ModelName, &s.Slug, &s.LastScrapedAt); err != nil {
			return nil, fmt.Errorf("scan subscription: %w", err)
		}
		subs = append(subs, s)
	}

	return subs, rows.Err()
}

func (r *SubscriptionRepository) UpdateLastScraped(ctx context.Context, id string, t time.Time) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE subscriptions SET last_scraped_at = $2 WHERE id = $1
	`, id, t)
	if err != nil {
		return fmt.Errorf("update last_scraped_at: %w", err)
	}
	return nil
}
