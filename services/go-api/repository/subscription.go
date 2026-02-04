package repository

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func isTableNotExist(err error) bool {
	return err != nil && strings.Contains(err.Error(), "does not exist")
}

type Subscription struct {
	ID                     uuid.UUID
	UserID                 uuid.UUID
	SubscriptionPlanID     uuid.UUID
	Platform               string
	PlatformSubscriptionID *string
	StartDate              time.Time
	ExpiryDate             *time.Time
	IsAutoRenewing         bool
	Status                 string
	CreatedAt              time.Time
}

type SubscriptionPlan struct {
	ID                   uuid.UUID
	PlanType             string
	FeedsLimit           int
	SourcesPerFeedLimit  int
	PriceAmountMicros    int64
	IsActive             bool
}

type SubscriptionRepository struct {
	pool *pgxpool.Pool
}

func NewSubscriptionRepository(pool *pgxpool.Pool) *SubscriptionRepository {
	return &SubscriptionRepository{pool: pool}
}

func (r *SubscriptionRepository) GetCurrentSubscription(ctx context.Context, userID uuid.UUID) (*Subscription, error) {
	query := `
		SELECT id, user_id, subscription_plan_id, platform, platform_subscription_id,
		       start_date, expiry_date, is_auto_renewing, status, created_at
		FROM user_subscriptions
		WHERE user_id = $1
		  AND status = 'ACTIVE'
		  AND (expiry_date IS NULL OR expiry_date > NOW())
		ORDER BY created_at DESC
		LIMIT 1`

	var s Subscription
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&s.ID, &s.UserID, &s.SubscriptionPlanID, &s.Platform, &s.PlatformSubscriptionID,
		&s.StartDate, &s.ExpiryDate, &s.IsAutoRenewing, &s.Status, &s.CreatedAt,
	)
	if err == pgx.ErrNoRows || isTableNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SubscriptionRepository) GetPlanByID(ctx context.Context, planID uuid.UUID) (*SubscriptionPlan, error) {
	query := `
		SELECT id, plan_type, feeds_limit, sources_per_feed_limit,
		       price_amount_micros, is_active
		FROM subscription_plans
		WHERE id = $1`

	var p SubscriptionPlan
	err := r.pool.QueryRow(ctx, query, planID).Scan(
		&p.ID, &p.PlanType, &p.FeedsLimit, &p.SourcesPerFeedLimit,
		&p.PriceAmountMicros, &p.IsActive,
	)
	if err == pgx.ErrNoRows || isTableNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *SubscriptionRepository) GetFreePlan(ctx context.Context) (*SubscriptionPlan, error) {
	query := `
		SELECT id, plan_type, feeds_limit, sources_per_feed_limit,
		       price_amount_micros, is_active
		FROM subscription_plans
		WHERE price_amount_micros = 0 AND is_active = true
		LIMIT 1`

	var p SubscriptionPlan
	err := r.pool.QueryRow(ctx, query).Scan(
		&p.ID, &p.PlanType, &p.FeedsLimit, &p.SourcesPerFeedLimit,
		&p.PriceAmountMicros, &p.IsActive,
	)
	if err == pgx.ErrNoRows || isTableNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *SubscriptionRepository) GetPlanByType(ctx context.Context, planType string) (*SubscriptionPlan, error) {
	query := `
		SELECT id, plan_type, feeds_limit, sources_per_feed_limit,
		       price_amount_micros, is_active
		FROM subscription_plans
		WHERE plan_type = $1 AND is_active = true
		LIMIT 1`

	var p SubscriptionPlan
	err := r.pool.QueryRow(ctx, query, planType).Scan(
		&p.ID, &p.PlanType, &p.FeedsLimit, &p.SourcesPerFeedLimit,
		&p.PriceAmountMicros, &p.IsActive,
	)
	if err == pgx.ErrNoRows || isTableNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

type CreateSubscriptionParams struct {
	UserID     uuid.UUID
	PlanID     uuid.UUID
	Status     string
	Platform   string
	ExternalID *string
	ExpiresAt  *time.Time
}

func (r *SubscriptionRepository) DeactivateUserSubscriptions(ctx context.Context, userID uuid.UUID) error {
	query := `UPDATE user_subscriptions SET status = 'CANCELLED', updated_at = NOW() WHERE user_id = $1 AND status = 'ACTIVE'`
	_, err := r.pool.Exec(ctx, query, userID)
	return err
}

func (r *SubscriptionRepository) GetByPlatformSubscriptionID(ctx context.Context, platformSubscriptionID string) (*Subscription, error) {
	query := `
		SELECT id, user_id, subscription_plan_id, platform, platform_subscription_id,
		       start_date, expiry_date, is_auto_renewing, status, created_at
		FROM user_subscriptions
		WHERE platform_subscription_id = $1
		ORDER BY created_at DESC
		LIMIT 1`

	var s Subscription
	err := r.pool.QueryRow(ctx, query, platformSubscriptionID).Scan(
		&s.ID, &s.UserID, &s.SubscriptionPlanID, &s.Platform, &s.PlatformSubscriptionID,
		&s.StartDate, &s.ExpiryDate, &s.IsAutoRenewing, &s.Status, &s.CreatedAt,
	)
	if err == pgx.ErrNoRows || isTableNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SubscriptionRepository) Create(ctx context.Context, params CreateSubscriptionParams) (*Subscription, error) {
	query := `
		INSERT INTO user_subscriptions (user_id, subscription_plan_id, status, platform,
		                                platform_subscription_id, start_date, expiry_date)
		VALUES ($1, $2, $3, $4, $5, NOW(), $6)
		RETURNING id, user_id, subscription_plan_id, platform, platform_subscription_id,
		          start_date, expiry_date, is_auto_renewing, status, created_at`

	var s Subscription
	err := r.pool.QueryRow(ctx, query,
		params.UserID, params.PlanID, params.Status, params.Platform,
		params.ExternalID, params.ExpiresAt,
	).Scan(
		&s.ID, &s.UserID, &s.SubscriptionPlanID, &s.Platform, &s.PlatformSubscriptionID,
		&s.StartDate, &s.ExpiryDate, &s.IsAutoRenewing, &s.Status, &s.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &s, nil
}
