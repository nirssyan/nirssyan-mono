package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SubscriptionRepository struct {
	pool *pgxpool.Pool
}

func NewSubscriptionRepository(pool *pgxpool.Pool) *SubscriptionRepository {
	return &SubscriptionRepository{pool: pool}
}

func (r *SubscriptionRepository) EnsureFreeSubscription(ctx context.Context, userID uuid.UUID) error {
	query := `
		INSERT INTO user_subscriptions (user_id, subscription_plan_id, status, platform, start_date, expiry_date)
		SELECT $1, sp.id, 'ACTIVE', 'SYSTEM', NOW(), '9999-12-31T23:59:59Z'
		FROM subscription_plans sp
		WHERE sp.price_amount_micros = 0 AND sp.is_active = true
		  AND NOT EXISTS (
			SELECT 1 FROM user_subscriptions us WHERE us.user_id = $1
		  )
		LIMIT 1`

	_, err := r.pool.Exec(ctx, query, userID)
	return err
}
