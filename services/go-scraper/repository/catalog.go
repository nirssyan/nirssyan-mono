package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type CatalogEntry struct {
	VendorID   int
	VendorName string
	ModelName  string
	LotCount   int
}

type CatalogRepository struct {
	pool *pgxpool.Pool
}

func NewCatalogRepository(pool *pgxpool.Pool) *CatalogRepository {
	return &CatalogRepository{pool: pool}
}

func (r *CatalogRepository) UpsertCatalog(ctx context.Context, entries []CatalogEntry) error {
	if len(entries) == 0 {
		return nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, e := range entries {
		_, err := tx.Exec(ctx, `
			INSERT INTO aucjp_catalog (vendor_id, vendor_name, model_name, lot_count, updated_at)
			VALUES ($1, $2, $3, $4, NOW())
			ON CONFLICT (vendor_id, model_name)
			DO UPDATE SET vendor_name = EXCLUDED.vendor_name,
			              lot_count = EXCLUDED.lot_count,
			              updated_at = NOW()
		`, e.VendorID, e.VendorName, e.ModelName, e.LotCount)
		if err != nil {
			return fmt.Errorf("upsert catalog entry: %w", err)
		}
	}

	return tx.Commit(ctx)
}
