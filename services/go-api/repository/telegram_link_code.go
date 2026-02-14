package repository

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TelegramLinkCode struct {
	Code      string
	UserID    uuid.UUID
	ExpiresAt time.Time
	CreatedAt time.Time
}

type TelegramLinkCodeRepository struct {
	pool *pgxpool.Pool
}

func NewTelegramLinkCodeRepository(pool *pgxpool.Pool) *TelegramLinkCodeRepository {
	return &TelegramLinkCodeRepository{pool: pool}
}

func (r *TelegramLinkCodeRepository) Create(ctx context.Context, userID uuid.UUID, expiresAt time.Time) (*TelegramLinkCode, error) {
	code, err := generateSecureCode(6)
	if err != nil {
		return nil, err
	}

	query := `
		INSERT INTO telegram_link_codes (code, user_id, expires_at)
		VALUES ($1, $2, $3)
		RETURNING code, user_id, expires_at, created_at`

	var tlc TelegramLinkCode
	err = r.pool.QueryRow(ctx, query, code, userID, expiresAt).Scan(
		&tlc.Code, &tlc.UserID, &tlc.ExpiresAt, &tlc.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &tlc, nil
}

func generateSecureCode(length int) (string, error) {
	bytes := make([]byte, length)
	_, err := rand.Read(bytes)
	if err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(bytes)[:length+2], nil
}
