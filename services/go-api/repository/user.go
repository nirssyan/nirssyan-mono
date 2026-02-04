package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID        uuid.UUID
	CreatedAt time.Time
	Email     *string
	IsAdmin   bool
	DeletedAt *time.Time
}

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

func (r *UserRepository) GetByID(ctx context.Context, userID uuid.UUID) (*User, error) {
	query := `
		SELECT id, created_at, email, is_admin, deleted_at
		FROM users
		WHERE id = $1`

	var u User
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&u.ID, &u.CreatedAt, &u.Email, &u.IsAdmin, &u.DeletedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) CreateIfNotExists(ctx context.Context, userID uuid.UUID, email *string) (*User, error) {
	query := `
		INSERT INTO users (id, email)
		VALUES ($1, $2)
		ON CONFLICT (id) DO NOTHING
		RETURNING id, created_at, email, is_admin, deleted_at`

	var u User
	err := r.pool.QueryRow(ctx, query, userID, email).Scan(
		&u.ID, &u.CreatedAt, &u.Email, &u.IsAdmin, &u.DeletedAt,
	)
	if err == pgx.ErrNoRows {
		return r.GetByID(ctx, userID)
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

type DeleteUserResult struct {
	UserID                 string `json:"user_id"`
	DeletedFeeds           int    `json:"deleted_feeds"`
	CancelledSubscriptions int    `json:"cancelled_subscriptions"`
	DeletedChats           int    `json:"deleted_chats"`
	DeletedTags            int    `json:"deleted_tags"`
	DeletedPostsSeen       int    `json:"deleted_posts_seen"`
	DeletedFeedbacks       int    `json:"deleted_feedbacks"`
	Message                string `json:"message"`
}

func (r *UserRepository) Delete(ctx context.Context, userID uuid.UUID) (*DeleteUserResult, error) {
	return r.SoftDelete(ctx, userID)
}

func (r *UserRepository) SoftDelete(ctx context.Context, userID uuid.UUID) (*DeleteUserResult, error) {
	// 1. Get user's feed_ids via users_feeds
	feedIDs, err := r.getUserFeedIDs(ctx, userID)
	if err != nil {
		return nil, err
	}

	// 2. Delete users_feeds (subscriptions)
	_, err = r.pool.Exec(ctx, `DELETE FROM users_feeds WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}

	// 3. Find and delete orphaned feeds
	deletedFeeds := 0
	for _, feedID := range feedIDs {
		var count int
		err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users_feeds WHERE feed_id = $1`, feedID).Scan(&count)
		if err != nil {
			continue
		}
		if count == 0 {
			// Delete orphaned feed (CASCADE will delete prompts, posts, sources)
			_, err = r.pool.Exec(ctx, `DELETE FROM feeds WHERE id = $1`, feedID)
			if err == nil {
				deletedFeeds++
			}
		}
	}

	// 4. Cancel active subscriptions
	result, err := r.pool.Exec(ctx, `UPDATE user_subscriptions SET status = 'CANCELLED', updated_at = NOW() WHERE user_id = $1 AND status = 'ACTIVE'`, userID)
	cancelledSubs := 0
	if err == nil {
		cancelledSubs = int(result.RowsAffected())
	}

	// 5. Delete user data
	var deletedChats, deletedTags, deletedPostsSeen, deletedFeedbacks int

	result, _ = r.pool.Exec(ctx, `DELETE FROM chats WHERE user_id = $1`, userID)
	deletedChats = int(result.RowsAffected())

	result, _ = r.pool.Exec(ctx, `DELETE FROM users_tags WHERE user_id = $1`, userID)
	deletedTags = int(result.RowsAffected())

	result, _ = r.pool.Exec(ctx, `DELETE FROM posts_seen WHERE user_id = $1`, userID)
	deletedPostsSeen = int(result.RowsAffected())

	result, _ = r.pool.Exec(ctx, `DELETE FROM feedbacks WHERE user_id = $1`, userID)
	deletedFeedbacks = int(result.RowsAffected())

	// 6. Delete telegram_users link
	r.pool.Exec(ctx, `DELETE FROM telegram_users WHERE user_id = $1`, userID)

	// 7. Delete device tokens
	r.pool.Exec(ctx, `DELETE FROM device_tokens WHERE user_id = $1`, userID)

	// 8. Set deleted_at timestamp (soft delete)
	_, err = r.pool.Exec(ctx, `UPDATE users SET deleted_at = NOW() WHERE id = $1`, userID)
	if err != nil {
		return nil, err
	}

	return &DeleteUserResult{
		UserID:                 userID.String(),
		DeletedFeeds:           deletedFeeds,
		CancelledSubscriptions: cancelledSubs,
		DeletedChats:           deletedChats,
		DeletedTags:            deletedTags,
		DeletedPostsSeen:       deletedPostsSeen,
		DeletedFeedbacks:       deletedFeedbacks,
		Message:                "User successfully deleted",
	}, nil
}

func (r *UserRepository) Reactivate(ctx context.Context, userID uuid.UUID) (bool, error) {
	result, err := r.pool.Exec(ctx,
		`UPDATE users SET deleted_at = NULL WHERE id = $1 AND deleted_at IS NOT NULL`,
		userID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

func (r *UserRepository) getUserFeedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx, `SELECT feed_id FROM users_feeds WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feedIDs []uuid.UUID
	for rows.Next() {
		var feedID uuid.UUID
		if err := rows.Scan(&feedID); err != nil {
			continue
		}
		feedIDs = append(feedIDs, feedID)
	}
	return feedIDs, nil
}

func (r *UserRepository) IsAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM admin_users WHERE user_id = $1 AND is_admin = true)`
	var isAdmin bool
	err := r.pool.QueryRow(ctx, query, userID).Scan(&isAdmin)
	if err != nil {
		return false, err
	}
	return isAdmin, nil
}
