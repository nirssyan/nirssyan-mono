package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DeviceToken struct {
	ID        int64
	UserID    uuid.UUID
	Token     string
	Platform  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type DeviceTokenRepository struct {
	pool *pgxpool.Pool
}

func NewDeviceTokenRepository(pool *pgxpool.Pool) *DeviceTokenRepository {
	return &DeviceTokenRepository{pool: pool}
}

func (r *DeviceTokenRepository) Upsert(ctx context.Context, userID uuid.UUID, token, platform string) (*DeviceToken, bool, error) {
	var existingID int64
	checkQuery := `SELECT id FROM device_tokens WHERE token = $1`
	err := r.pool.QueryRow(ctx, checkQuery, token).Scan(&existingID)
	isNew := err != nil

	query := `
		INSERT INTO device_tokens (user_id, token, platform, is_active, updated_at)
		VALUES ($1, $2, $3, true, NOW())
		ON CONFLICT (token) DO UPDATE SET user_id = $1, platform = $3, is_active = true, updated_at = NOW()
		RETURNING id, user_id, token, platform, created_at, updated_at`

	var t DeviceToken
	err = r.pool.QueryRow(ctx, query, userID, token, platform).Scan(
		&t.ID, &t.UserID, &t.Token, &t.Platform, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, false, err
	}
	return &t, isNew, nil
}

func (r *DeviceTokenRepository) Delete(ctx context.Context, userID uuid.UUID, token string) error {
	query := `UPDATE device_tokens SET is_active = false, updated_at = NOW() WHERE token = $1`
	_, err := r.pool.Exec(ctx, query, token)
	return err
}

func (r *DeviceTokenRepository) GetUserTokens(ctx context.Context, userID uuid.UUID) ([]DeviceToken, error) {
	query := `
		SELECT id, user_id, token, platform, created_at, updated_at
		FROM device_tokens
		WHERE user_id = $1`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []DeviceToken
	for rows.Next() {
		var t DeviceToken
		if err := rows.Scan(&t.ID, &t.UserID, &t.Token, &t.Platform, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}

	return tokens, rows.Err()
}
