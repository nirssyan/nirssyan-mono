package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Tag struct {
	ID   uuid.UUID
	Name string
	Slug string
}

type TagRepository struct {
	pool *pgxpool.Pool
}

func NewTagRepository(pool *pgxpool.Pool) *TagRepository {
	return &TagRepository{pool: pool}
}

func (r *TagRepository) GetAll(ctx context.Context) ([]Tag, error) {
	query := `SELECT id, name, slug FROM tags ORDER BY name`

	rows, err := r.pool.Query(ctx, query)
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

func (r *TagRepository) GetByID(ctx context.Context, tagID uuid.UUID) (*Tag, error) {
	query := `SELECT id, name, slug FROM tags WHERE id = $1`

	var t Tag
	err := r.pool.QueryRow(ctx, query, tagID).Scan(&t.ID, &t.Name, &t.Slug)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) ValidateTagIDs(ctx context.Context, tagIDs []uuid.UUID) ([]uuid.UUID, error) {
	if len(tagIDs) == 0 {
		return []uuid.UUID{}, nil
	}

	query := `SELECT id FROM tags WHERE id = ANY($1)`
	rows, err := r.pool.Query(ctx, query, tagIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var validIDs []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		validIDs = append(validIDs, id)
	}

	return validIDs, rows.Err()
}
