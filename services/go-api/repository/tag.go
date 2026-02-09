package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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

func (r *TagRepository) Create(ctx context.Context, name, slug string) (*Tag, error) {
	query := `
		INSERT INTO tags (name, slug)
		VALUES ($1, $2)
		RETURNING id, name, slug`

	var t Tag
	err := r.pool.QueryRow(ctx, query, name, slug).Scan(&t.ID, &t.Name, &t.Slug)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) Update(ctx context.Context, id uuid.UUID, name, slug *string) (*Tag, error) {
	query := `
		UPDATE tags
		SET name = COALESCE($2, name),
		    slug = COALESCE($3, slug)
		WHERE id = $1
		RETURNING id, name, slug`

	var t Tag
	err := r.pool.QueryRow(ctx, query, id, name, slug).Scan(&t.ID, &t.Name, &t.Slug)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) Delete(ctx context.Context, id uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, `DELETE FROM users_tags WHERE tag_id = $1`, id); err != nil {
		return fmt.Errorf("delete users_tags: %w", err)
	}

	result, err := tx.Exec(ctx, `DELETE FROM tags WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("delete tag: %w", err)
	}
	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return tx.Commit(ctx)
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
