package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/model"
)

var ErrTokenFamilyNotFound = errors.New("token family not found")

type TokenFamilyRepository struct {
	pool *pgxpool.Pool
}

func NewTokenFamilyRepository(pool *pgxpool.Pool) *TokenFamilyRepository {
	return &TokenFamilyRepository{pool: pool}
}

func (r *TokenFamilyRepository) Create(ctx context.Context, userID uuid.UUID) (*model.TokenFamily, error) {
	query := `
		INSERT INTO token_families (user_id, created_at)
		VALUES ($1, $2)
		RETURNING id, user_id, revoked, revoked_at, revoke_reason, created_at`

	var tf model.TokenFamily
	err := r.pool.QueryRow(ctx, query, userID, time.Now()).Scan(
		&tf.ID, &tf.UserID, &tf.Revoked, &tf.RevokedAt, &tf.RevokeReason, &tf.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &tf, nil
}

func (r *TokenFamilyRepository) GetByID(ctx context.Context, id uuid.UUID) (*model.TokenFamily, error) {
	query := `
		SELECT id, user_id, revoked, revoked_at, revoke_reason, created_at
		FROM token_families WHERE id = $1`

	var tf model.TokenFamily
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&tf.ID, &tf.UserID, &tf.Revoked, &tf.RevokedAt, &tf.RevokeReason, &tf.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrTokenFamilyNotFound
	}
	if err != nil {
		return nil, err
	}
	return &tf, nil
}

func (r *TokenFamilyRepository) Revoke(ctx context.Context, id uuid.UUID, reason string) error {
	query := `UPDATE token_families SET revoked = true, revoked_at = $2, revoke_reason = $3 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, time.Now(), reason)
	return err
}

func (r *TokenFamilyRepository) RevokeAllForUser(ctx context.Context, userID uuid.UUID, reason string) error {
	query := `UPDATE token_families SET revoked = true, revoked_at = $2, revoke_reason = $3 WHERE user_id = $1 AND revoked = false`
	_, err := r.pool.Exec(ctx, query, userID, time.Now(), reason)
	return err
}
