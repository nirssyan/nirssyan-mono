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

var ErrUserNotFound = errors.New("user not found")

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*model.User, error) {
	query := `
		SELECT id, email, provider, provider_id, password_hash, email_verified_at, created_at, updated_at
		FROM users WHERE id = $1`

	var u model.User
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.Provider, &u.ProviderID, &u.PasswordHash,
		&u.EmailVerifiedAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	query := `
		SELECT id, email, provider, provider_id, password_hash, email_verified_at, created_at, updated_at
		FROM users WHERE email = $1`

	var u model.User
	err := r.pool.QueryRow(ctx, query, email).Scan(
		&u.ID, &u.Email, &u.Provider, &u.ProviderID, &u.PasswordHash,
		&u.EmailVerifiedAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByProviderID(ctx context.Context, provider, providerID string) (*model.User, error) {
	query := `
		SELECT id, email, provider, provider_id, password_hash, email_verified_at, created_at, updated_at
		FROM users WHERE provider = $1 AND provider_id = $2`

	var u model.User
	err := r.pool.QueryRow(ctx, query, provider, providerID).Scan(
		&u.ID, &u.Email, &u.Provider, &u.ProviderID, &u.PasswordHash,
		&u.EmailVerifiedAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUserNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) Create(ctx context.Context, email, provider string, providerID *string) (*model.User, error) {
	query := `
		INSERT INTO users (email, provider, provider_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $4)
		RETURNING id, email, provider, provider_id, password_hash, email_verified_at, created_at, updated_at`

	now := time.Now()
	var u model.User
	err := r.pool.QueryRow(ctx, query, email, provider, providerID, now).Scan(
		&u.ID, &u.Email, &u.Provider, &u.ProviderID, &u.PasswordHash,
		&u.EmailVerifiedAt, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) UpdateProvider(ctx context.Context, id uuid.UUID, provider string, providerID *string) error {
	query := `UPDATE users SET provider = $2, provider_id = $3, updated_at = $4 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, provider, providerID, time.Now())
	return err
}

func (r *UserRepository) SetEmailVerified(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE users SET email_verified_at = $2, updated_at = $2 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, time.Now())
	return err
}

func (r *UserRepository) SetPasswordHash(ctx context.Context, id uuid.UUID, hash string) error {
	query := `UPDATE users SET password_hash = $2, updated_at = $3 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id, hash, time.Now())
	return err
}
