package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserTagRepository struct {
	pool *pgxpool.Pool
}

func NewUserTagRepository(pool *pgxpool.Pool) *UserTagRepository {
	return &UserTagRepository{pool: pool}
}

func (r *UserTagRepository) GetUserTags(ctx context.Context, userID uuid.UUID) ([]Tag, error) {
	query := `
		SELECT t.id, t.name, t.slug
		FROM tags t
		JOIN users_tags ut ON t.id = ut.tag_id
		WHERE ut.user_id = $1
		ORDER BY t.name`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tags []Tag
	for rows.Next() {
		var t Tag
		if err := rows.Scan(&t.ID, &t.Name, &t.Slug); err != nil {
			return nil, err
		}
		tags = append(tags, t)
	}

	return tags, rows.Err()
}

func (r *UserTagRepository) SetUserTags(ctx context.Context, userID uuid.UUID, tagIDs []string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM users_tags WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}

	if len(tagIDs) > 0 {
		for _, tagIDStr := range tagIDs {
			tagID, err := uuid.Parse(tagIDStr)
			if err != nil {
				continue
			}
			_, err = tx.Exec(ctx,
				`INSERT INTO users_tags (user_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
				userID, tagID)
			if err != nil {
				return err
			}
		}
	}

	return tx.Commit(ctx)
}
