package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MarketplaceRepository struct {
	pool *pgxpool.Pool
}

func NewMarketplaceRepository(pool *pgxpool.Pool) *MarketplaceRepository {
	return &MarketplaceRepository{pool: pool}
}

func (r *MarketplaceRepository) GetMarketplaceFeeds(ctx context.Context, limit, offset int) ([]Feed, error) {
	query := `
		SELECT id, created_at, name, type, description, tags,
		       is_marketplace, is_creating_finished, chat_id
		FROM feeds
		WHERE is_marketplace = true AND is_creating_finished = true
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2`

	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feeds []Feed
	for rows.Next() {
		var f Feed
		if err := rows.Scan(
			&f.ID, &f.CreatedAt, &f.Name, &f.Type, &f.Description, &f.Tags,
			&f.IsMarketplace, &f.IsCreatingFinished, &f.ChatID,
		); err != nil {
			return nil, err
		}
		feeds = append(feeds, f)
	}

	return feeds, rows.Err()
}

func (r *MarketplaceRepository) SetMarketplace(ctx context.Context, feedID uuid.UUID, isMarketplace bool) error {
	query := `UPDATE feeds SET is_marketplace = $2 WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, feedID, isMarketplace)
	return err
}
