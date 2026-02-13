package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RawFeed struct {
	ID        uuid.UUID
	CreatedAt time.Time
	Name      string
	FeedURL   string
	RawType   string
}

type RawFeedRepository struct {
	pool *pgxpool.Pool
}

func NewRawFeedRepository(pool *pgxpool.Pool) *RawFeedRepository {
	return &RawFeedRepository{pool: pool}
}

func (r *RawFeedRepository) GetOrCreate(ctx context.Context, feedURL, rawType, name string) (*RawFeed, error) {
	normalizedURL := normalizeTelegramURL(feedURL)

	query := `SELECT id, created_at, name, feed_url, raw_type FROM raw_feeds WHERE feed_url = $1 OR site_url = $1`

	var rf RawFeed
	err := r.pool.QueryRow(ctx, query, normalizedURL).Scan(
		&rf.ID, &rf.CreatedAt, &rf.Name, &rf.FeedURL, &rf.RawType,
	)
	if err == nil {
		return &rf, nil
	}
	if err != pgx.ErrNoRows {
		return nil, err
	}

	insertQuery := `
		INSERT INTO raw_feeds (name, feed_url, site_url, raw_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at, name, feed_url, raw_type`

	err = r.pool.QueryRow(ctx, insertQuery, name, normalizedURL, normalizedURL, rawType).Scan(
		&rf.ID, &rf.CreatedAt, &rf.Name, &rf.FeedURL, &rf.RawType,
	)
	if err != nil {
		return nil, err
	}
	return &rf, nil
}

func normalizeTelegramURL(url string) string {
	if len(url) > 0 && url[0] == '@' {
		return "https://t.me/" + url[1:]
	}
	return url
}

func (r *RawFeedRepository) LinkToPrompt(ctx context.Context, promptID, rawFeedID uuid.UUID) error {
	query := `
		INSERT INTO prompts_raw_feeds (prompt_id, raw_feed_id)
		VALUES ($1, $2)
		ON CONFLICT (prompt_id, raw_feed_id) DO NOTHING`

	_, err := r.pool.Exec(ctx, query, promptID, rawFeedID)
	return err
}

func (r *RawFeedRepository) GetByFeedID(ctx context.Context, feedID uuid.UUID) ([]RawFeed, error) {
	query := `SELECT rf.id, rf.created_at, rf.name, rf.feed_url, rf.raw_type
	          FROM raw_feeds rf
	          JOIN prompts_raw_feeds prf ON prf.raw_feed_id = rf.id
	          JOIN prompts p ON prf.prompt_id = p.id
	          WHERE p.feed_id = $1`

	rows, err := r.pool.Query(ctx, query, feedID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feeds []RawFeed
	for rows.Next() {
		var rf RawFeed
		if err := rows.Scan(&rf.ID, &rf.CreatedAt, &rf.Name, &rf.FeedURL, &rf.RawType); err != nil {
			return nil, err
		}
		feeds = append(feeds, rf)
	}
	return feeds, rows.Err()
}

// FindIDsByURLs returns raw_feed IDs for the given URLs (checking both feed_url and site_url)
func (r *RawFeedRepository) FindIDsByURLs(ctx context.Context, urls []string) ([]uuid.UUID, error) {
	if len(urls) == 0 {
		return nil, nil
	}

	// Normalize URLs
	normalizedURLs := make([]string, len(urls))
	for i, u := range urls {
		normalizedURLs[i] = normalizeTelegramURL(u)
	}

	query := `SELECT id FROM raw_feeds WHERE feed_url = ANY($1) OR site_url = ANY($1)`

	rows, err := r.pool.Query(ctx, query, normalizedURLs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}

	return ids, rows.Err()
}
