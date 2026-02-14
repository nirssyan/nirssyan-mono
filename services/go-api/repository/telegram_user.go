package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TelegramUser struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	TelegramID int64
	Username   *string
	FirstName  *string
	LinkedAt   time.Time
}

type TelegramUserRepository struct {
	pool *pgxpool.Pool
}

func NewTelegramUserRepository(pool *pgxpool.Pool) *TelegramUserRepository {
	return &TelegramUserRepository{pool: pool}
}

func (r *TelegramUserRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*TelegramUser, error) {
	query := `
		SELECT id, user_id, telegram_id, telegram_username, telegram_first_name, linked_at
		FROM telegram_users
		WHERE user_id = $1 AND is_active = true`

	var t TelegramUser
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&t.ID, &t.UserID, &t.TelegramID, &t.Username, &t.FirstName, &t.LinkedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *TelegramUserRepository) DeleteByUserID(ctx context.Context, userID uuid.UUID) error {
	query := `DELETE FROM telegram_users WHERE user_id = $1`
	_, err := r.pool.Exec(ctx, query, userID)
	return err
}

func (r *TelegramUserRepository) UnlinkByUserID(ctx context.Context, userID uuid.UUID) (bool, error) {
	query := `UPDATE telegram_users SET is_active = false WHERE user_id = $1 AND is_active = true`
	result, err := r.pool.Exec(ctx, query, userID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}
