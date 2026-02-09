package repository

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MarketplaceFeed struct {
	ID          uuid.UUID
	CreatedAt   time.Time
	Slug        string
	Name        string
	Type        string
	Description *string
	Tags        []string
	Sources     json.RawMessage
	Story       *string
}

type CreateMarketplaceFeedParams struct {
	Slug        string
	Name        string
	Type        string
	Description *string
	Tags        []string
	Sources     json.RawMessage
	Story       *string
}

type MarketplaceRepository struct {
	pool *pgxpool.Pool
}

func NewMarketplaceRepository(pool *pgxpool.Pool) *MarketplaceRepository {
	return &MarketplaceRepository{pool: pool}
}

func (r *MarketplaceRepository) GetAll(ctx context.Context, limit, offset int) ([]MarketplaceFeed, error) {
	query := `
		SELECT id, created_at, slug, name, type, description, tags, sources, story
		FROM marketplace_feeds
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2`

	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feeds []MarketplaceFeed
	for rows.Next() {
		var f MarketplaceFeed
		if err := rows.Scan(
			&f.ID, &f.CreatedAt, &f.Slug, &f.Name, &f.Type,
			&f.Description, &f.Tags, &f.Sources, &f.Story,
		); err != nil {
			return nil, err
		}
		feeds = append(feeds, f)
	}

	return feeds, rows.Err()
}

func (r *MarketplaceRepository) GetBySlug(ctx context.Context, slug string) (*MarketplaceFeed, error) {
	query := `
		SELECT id, created_at, slug, name, type, description, tags, sources, story
		FROM marketplace_feeds
		WHERE slug = $1`

	var f MarketplaceFeed
	err := r.pool.QueryRow(ctx, query, slug).Scan(
		&f.ID, &f.CreatedAt, &f.Slug, &f.Name, &f.Type,
		&f.Description, &f.Tags, &f.Sources, &f.Story,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &f, nil
}

func (r *MarketplaceRepository) Create(ctx context.Context, p CreateMarketplaceFeedParams) (*MarketplaceFeed, error) {
	query := `
		INSERT INTO marketplace_feeds (slug, name, type, description, tags, sources, story)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, slug, name, type, description, tags, sources, story`

	var f MarketplaceFeed
	err := r.pool.QueryRow(ctx, query,
		p.Slug, p.Name, p.Type, p.Description, p.Tags, p.Sources, p.Story,
	).Scan(
		&f.ID, &f.CreatedAt, &f.Slug, &f.Name, &f.Type,
		&f.Description, &f.Tags, &f.Sources, &f.Story,
	)
	if err != nil {
		return nil, err
	}

	return &f, nil
}
