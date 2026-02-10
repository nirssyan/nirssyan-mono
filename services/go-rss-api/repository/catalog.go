package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Vendor struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type Model struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

type CatalogRepository struct {
	pool *pgxpool.Pool
}

func NewCatalogRepository(pool *pgxpool.Pool) *CatalogRepository {
	return &CatalogRepository{pool: pool}
}

func (r *CatalogRepository) GetVendors(ctx context.Context) ([]Vendor, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT vendor_id, vendor_name FROM aucjp_catalog ORDER BY vendor_name`)
	if err != nil {
		return nil, fmt.Errorf("query vendors: %w", err)
	}
	defer rows.Close()

	var vendors []Vendor
	for rows.Next() {
		var v Vendor
		if err := rows.Scan(&v.ID, &v.Name); err != nil {
			return nil, fmt.Errorf("scan vendor: %w", err)
		}
		vendors = append(vendors, v)
	}
	return vendors, rows.Err()
}

func (r *CatalogRepository) GetModels(ctx context.Context, vendorID int) ([]Model, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT model_name, lot_count FROM aucjp_catalog WHERE vendor_id = $1 ORDER BY model_name`, vendorID)
	if err != nil {
		return nil, fmt.Errorf("query models: %w", err)
	}
	defer rows.Close()

	var models []Model
	for rows.Next() {
		var m Model
		if err := rows.Scan(&m.Name, &m.Count); err != nil {
			return nil, fmt.Errorf("scan model: %w", err)
		}
		models = append(models, m)
	}
	return models, rows.Err()
}

func (r *CatalogRepository) GetVendorName(ctx context.Context, vendorID int) (string, error) {
	var name string
	err := r.pool.QueryRow(ctx,
		`SELECT vendor_name FROM aucjp_catalog WHERE vendor_id = $1 LIMIT 1`, vendorID).Scan(&name)
	if err != nil {
		return "", fmt.Errorf("get vendor name: %w", err)
	}
	return name, nil
}

func (r *CatalogRepository) GetVendorIDByName(ctx context.Context, name string) (int, error) {
	var id int
	err := r.pool.QueryRow(ctx,
		`SELECT vendor_id FROM aucjp_catalog WHERE LOWER(vendor_name) = LOWER($1) LIMIT 1`, name).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("get vendor id by name: %w", err)
	}
	return id, nil
}
