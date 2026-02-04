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

var ErrMagicLinkNotFound = errors.New("magic link token not found")

type MagicLinkRepository struct {
	pool *pgxpool.Pool
}

func NewMagicLinkRepository(pool *pgxpool.Pool) *MagicLinkRepository {
	return &MagicLinkRepository{pool: pool}
}

func (r *MagicLinkRepository) Create(ctx context.Context, email, tokenHash string, userID *uuid.UUID, expiresAt time.Time) (*model.MagicLinkToken, error) {
	query := `
		INSERT INTO magic_link_tokens (email, token_hash, user_id, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, email, token_hash, user_id, expires_at, used_at, created_at`

	var ml model.MagicLinkToken
	err := r.pool.QueryRow(ctx, query, email, tokenHash, userID, expiresAt, time.Now()).Scan(
		&ml.ID, &ml.Email, &ml.TokenHash, &ml.UserID, &ml.ExpiresAt, &ml.UsedAt, &ml.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &ml, nil
}

func (r *MagicLinkRepository) GetByHash(ctx context.Context, tokenHash string) (*model.MagicLinkToken, error) {
	query := `
		SELECT id, email, token_hash, user_id, expires_at, used_at, created_at
		FROM magic_link_tokens WHERE token_hash = $1`

	var ml model.MagicLinkToken
	err := r.pool.QueryRow(ctx, query, tokenHash).Scan(
		&ml.ID, &ml.Email, &ml.TokenHash, &ml.UserID, &ml.ExpiresAt, &ml.UsedAt, &ml.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrMagicLinkNotFound
	}
	if err != nil {
		return nil, err
	}
	return &ml, nil
}

func (r *MagicLinkRepository) MarkUsed(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE magic_link_tokens SET used_at = $2 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, time.Now())
	return err
}

func (r *MagicLinkRepository) DeleteExpired(ctx context.Context) (int64, error) {
	query := `DELETE FROM magic_link_tokens WHERE expires_at < $1`
	result, err := r.pool.Exec(ctx, query, time.Now())
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}
