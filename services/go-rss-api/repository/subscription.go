package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Subscription struct {
	ID        string `json:"id"`
	VendorID  int    `json:"vendor_id"`
	ModelName string `json:"model_name"`
	Slug      string `json:"slug"`
}

type SubscriptionRepository struct {
	pool *pgxpool.Pool
}

func NewSubscriptionRepository(pool *pgxpool.Pool) *SubscriptionRepository {
	return &SubscriptionRepository{pool: pool}
}

func (r *SubscriptionRepository) GetBySlug(ctx context.Context, slug string) (*Subscription, error) {
	var s Subscription
	err := r.pool.QueryRow(ctx,
		`SELECT id, vendor_id, model_name, slug FROM subscriptions WHERE slug = $1`, slug).
		Scan(&s.ID, &s.VendorID, &s.ModelName, &s.Slug)
	if err != nil {
		return nil, fmt.Errorf("get subscription by slug: %w", err)
	}
	return &s, nil
}

func (r *SubscriptionRepository) GetByVendorModel(ctx context.Context, vendorID int, modelName string) (*Subscription, error) {
	var s Subscription
	err := r.pool.QueryRow(ctx,
		`SELECT id, vendor_id, model_name, slug FROM subscriptions WHERE vendor_id = $1 AND model_name = $2`,
		vendorID, modelName).
		Scan(&s.ID, &s.VendorID, &s.ModelName, &s.Slug)
	if err != nil {
		return nil, fmt.Errorf("get subscription by vendor/model: %w", err)
	}
	return &s, nil
}

func (r *SubscriptionRepository) Create(ctx context.Context, sub *Subscription) error {
	sub.ID = uuid.New().String()
	_, err := r.pool.Exec(ctx,
		`INSERT INTO subscriptions (id, vendor_id, model_name, slug) VALUES ($1, $2, $3, $4)`,
		sub.ID, sub.VendorID, sub.ModelName, sub.Slug)
	if err != nil {
		return fmt.Errorf("create subscription: %w", err)
	}
	return nil
}
