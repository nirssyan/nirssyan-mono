package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SuggestionName struct {
	En string `json:"en"`
	Ru string `json:"ru"`
}

func (s *SuggestionName) Scan(src any) error {
	switch v := src.(type) {
	case []byte:
		return json.Unmarshal(v, s)
	case string:
		return json.Unmarshal([]byte(v), s)
	default:
		return fmt.Errorf("cannot scan %T into SuggestionName", src)
	}
}

type Suggestion struct {
	ID         uuid.UUID
	Name       SuggestionName
	Type       string
	SourceType *string
}

type SuggestionRepository struct {
	pool *pgxpool.Pool
}

func NewSuggestionRepository(pool *pgxpool.Pool) *SuggestionRepository {
	return &SuggestionRepository{pool: pool}
}

func (r *SuggestionRepository) GetByType(ctx context.Context, suggestionType string) ([]Suggestion, error) {
	query := `
		SELECT id, name, type, source_type
		FROM suggestions
		WHERE type = $1
		ORDER BY name`

	rows, err := r.pool.Query(ctx, query, suggestionType)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var suggestions []Suggestion
	for rows.Next() {
		var s Suggestion
		if err := rows.Scan(&s.ID, &s.Name, &s.Type, &s.SourceType); err != nil {
			return nil, err
		}
		suggestions = append(suggestions, s)
	}

	return suggestions, rows.Err()
}

func (r *SuggestionRepository) GetAll(ctx context.Context) ([]Suggestion, error) {
	query := `
		SELECT id, name, type, source_type
		FROM suggestions
		ORDER BY type, name`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var suggestions []Suggestion
	for rows.Next() {
		var s Suggestion
		if err := rows.Scan(&s.ID, &s.Name, &s.Type, &s.SourceType); err != nil {
			return nil, err
		}
		suggestions = append(suggestions, s)
	}

	return suggestions, rows.Err()
}

func (r *SuggestionRepository) GetByID(ctx context.Context, id uuid.UUID) (*Suggestion, error) {
	query := `SELECT id, name, type, source_type FROM suggestions WHERE id = $1`

	var s Suggestion
	err := r.pool.QueryRow(ctx, query, id).Scan(&s.ID, &s.Name, &s.Type, &s.SourceType)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SuggestionRepository) Create(ctx context.Context, sType string, name SuggestionName, sourceType *string) (*Suggestion, error) {
	nameJSON, err := json.Marshal(name)
	if err != nil {
		return nil, fmt.Errorf("marshal name: %w", err)
	}

	query := `
		INSERT INTO suggestions (type, name, source_type)
		VALUES ($1, $2, $3)
		RETURNING id, name, type, source_type`

	var s Suggestion
	err = r.pool.QueryRow(ctx, query, sType, nameJSON, sourceType).Scan(&s.ID, &s.Name, &s.Type, &s.SourceType)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SuggestionRepository) Update(ctx context.Context, id uuid.UUID, name *SuggestionName, sourceType *string) (*Suggestion, error) {
	var nameJSON []byte
	if name != nil {
		var err error
		nameJSON, err = json.Marshal(name)
		if err != nil {
			return nil, fmt.Errorf("marshal name: %w", err)
		}
	}

	query := `
		UPDATE suggestions
		SET name = COALESCE($2, name),
		    source_type = COALESCE($3, source_type)
		WHERE id = $1
		RETURNING id, name, type, source_type`

	var s Suggestion
	err := r.pool.QueryRow(ctx, query, id, nameJSON, sourceType).Scan(&s.ID, &s.Name, &s.Type, &s.SourceType)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SuggestionRepository) Delete(ctx context.Context, id uuid.UUID) error {
	result, err := r.pool.Exec(ctx, `DELETE FROM suggestions WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// ResolveSuggestionNames converts UUIDs to human-readable names from suggestions table.
// If item is not a valid UUID or not found, it's returned as-is.
func (r *SuggestionRepository) ResolveSuggestionNames(ctx context.Context, items []string) []string {
	if len(items) == 0 {
		return items
	}

	var uuids []uuid.UUID
	indexMap := make(map[string]int) // uuid string -> original index

	result := make([]string, len(items))
	for i, item := range items {
		if id, err := uuid.Parse(item); err == nil {
			uuids = append(uuids, id)
			indexMap[item] = i
			result[i] = item // placeholder, will be replaced if found
		} else {
			result[i] = item // Keep text as-is
		}
	}

	if len(uuids) == 0 {
		return items // No UUIDs to resolve
	}

	rows, err := r.pool.Query(ctx, `
		SELECT id, name
		FROM suggestions
		WHERE id = ANY($1)
	`, uuids)
	if err != nil {
		return result
	}
	defer rows.Close()

	for rows.Next() {
		var id uuid.UUID
		var name SuggestionName
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		// Prefer Russian name, fallback to English
		resolvedName := ""
		if name.Ru != "" {
			resolvedName = name.Ru
		} else if name.En != "" {
			resolvedName = name.En
		}
		if resolvedName != "" {
			if idx, ok := indexMap[id.String()]; ok {
				result[idx] = resolvedName
			}
		}
	}

	return result
}
