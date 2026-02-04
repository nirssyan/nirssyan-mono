package repository

import (
	"context"
	"errors"
	"net"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/model"
)

var ErrRefreshTokenNotFound = errors.New("refresh token not found")

type RefreshTokenRepository struct {
	pool *pgxpool.Pool
}

func NewRefreshTokenRepository(pool *pgxpool.Pool) *RefreshTokenRepository {
	return &RefreshTokenRepository{pool: pool}
}

func (r *RefreshTokenRepository) Create(ctx context.Context, tokenHash string, userID, familyID uuid.UUID, expiresAt time.Time, deviceInfo *string, ipAddress net.IP) (*model.RefreshToken, error) {
	query := `
		INSERT INTO refresh_tokens (token_hash, user_id, family_id, expires_at, device_info, ip_address, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, token_hash, user_id, family_id, used, device_info, ip_address, expires_at, created_at`

	var rt model.RefreshToken
	err := r.pool.QueryRow(ctx, query, tokenHash, userID, familyID, expiresAt, deviceInfo, ipAddress, time.Now()).Scan(
		&rt.ID, &rt.TokenHash, &rt.UserID, &rt.FamilyID, &rt.Used, &rt.DeviceInfo, &rt.IPAddress, &rt.ExpiresAt, &rt.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &rt, nil
}

func (r *RefreshTokenRepository) GetByHash(ctx context.Context, tokenHash string) (*model.RefreshToken, error) {
	query := `
		SELECT id, token_hash, user_id, family_id, used, device_info, ip_address, expires_at, created_at
		FROM refresh_tokens WHERE token_hash = $1`

	var rt model.RefreshToken
	err := r.pool.QueryRow(ctx, query, tokenHash).Scan(
		&rt.ID, &rt.TokenHash, &rt.UserID, &rt.FamilyID, &rt.Used, &rt.DeviceInfo, &rt.IPAddress, &rt.ExpiresAt, &rt.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrRefreshTokenNotFound
	}
	if err != nil {
		return nil, err
	}
	return &rt, nil
}

func (r *RefreshTokenRepository) MarkUsed(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE refresh_tokens SET used = true WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

func (r *RefreshTokenRepository) DeleteByFamily(ctx context.Context, familyID uuid.UUID) error {
	query := `DELETE FROM refresh_tokens WHERE family_id = $1`
	_, err := r.pool.Exec(ctx, query, familyID)
	return err
}

func (r *RefreshTokenRepository) DeleteExpired(ctx context.Context) (int64, error) {
	query := `DELETE FROM refresh_tokens WHERE expires_at < $1`
	result, err := r.pool.Exec(ctx, query, time.Now())
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}
