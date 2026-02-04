package repository

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostCursor struct {
	CreatedAt string `json:"created_at"`
	ID        string `json:"id"`
}

func EncodeCursor(createdAt time.Time, id uuid.UUID) string {
	cursor := PostCursor{
		CreatedAt: createdAt.Format(time.RFC3339),
		ID:        id.String(),
	}
	data, _ := json.Marshal(cursor)
	return base64.StdEncoding.EncodeToString(data)
}

func DecodeCursor(cursor string) (time.Time, uuid.UUID, error) {
	data, err := base64.StdEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, uuid.Nil, err
	}

	var c PostCursor
	if err := json.Unmarshal(data, &c); err != nil {
		return time.Time{}, uuid.Nil, err
	}

	createdAt, err := time.Parse(time.RFC3339, c.CreatedAt)
	if err != nil {
		return time.Time{}, uuid.Nil, err
	}

	id, err := uuid.Parse(c.ID)
	if err != nil {
		return time.Time{}, uuid.Nil, err
	}

	return createdAt, id, nil
}

type Post struct {
	ID                          uuid.UUID
	CreatedAt                   time.Time
	FeedID                      uuid.UUID
	Title                       *string
	ImageURL                    *string
	MediaObjects                json.RawMessage
	Views                       map[string]string
	ModerationAction            *string
	ModerationLabels            []string
	ModerationMatchedEntities   []string
	Sources                     []PostSource
}

type PostSource struct {
	ID        uuid.UUID `json:"id"`
	SourceURL string    `json:"source_url"`
}

type PostRepository struct {
	pool *pgxpool.Pool
}

func NewPostRepository(pool *pgxpool.Pool) *PostRepository {
	return &PostRepository{pool: pool}
}

func (r *PostRepository) GetByID(ctx context.Context, postID uuid.UUID) (*Post, error) {
	query := `
		SELECT p.id, p.created_at, p.feed_id, p.title, p.image_url,
		       p.media_objects, p.views, p.moderation_action, p.moderation_labels,
		       p.moderation_matched_entities
		FROM posts p
		WHERE p.id = $1`

	var p Post
	var viewsJSON []byte
	err := r.pool.QueryRow(ctx, query, postID).Scan(
		&p.ID, &p.CreatedAt, &p.FeedID, &p.Title, &p.ImageURL,
		&p.MediaObjects, &viewsJSON, &p.ModerationAction, &p.ModerationLabels,
		&p.ModerationMatchedEntities,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	if viewsJSON != nil {
		if err := json.Unmarshal(viewsJSON, &p.Views); err != nil {
			return nil, err
		}
	}

	sources, err := r.getPostSources(ctx, postID)
	if err != nil {
		return nil, err
	}
	p.Sources = sources

	return &p, nil
}

func (r *PostRepository) GetFeedPosts(ctx context.Context, feedID uuid.UUID, limit, offset int) ([]Post, error) {
	query := `
		SELECT p.id, p.created_at, p.feed_id, p.title, p.image_url,
		       p.media_objects, p.views, p.moderation_action, p.moderation_labels,
		       p.moderation_matched_entities
		FROM posts p
		WHERE p.feed_id = $1
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3`

	rows, err := r.pool.Query(ctx, query, feedID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []Post
	for rows.Next() {
		var p Post
		var viewsJSON []byte
		if err := rows.Scan(
			&p.ID, &p.CreatedAt, &p.FeedID, &p.Title, &p.ImageURL,
			&p.MediaObjects, &viewsJSON, &p.ModerationAction, &p.ModerationLabels,
			&p.ModerationMatchedEntities,
		); err != nil {
			return nil, err
		}

		if viewsJSON != nil {
			if err := json.Unmarshal(viewsJSON, &p.Views); err != nil {
				return nil, err
			}
		}

		posts = append(posts, p)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i := range posts {
		sources, err := r.getPostSources(ctx, posts[i].ID)
		if err != nil {
			return nil, err
		}
		posts[i].Sources = sources
	}

	return posts, nil
}

func (r *PostRepository) getPostSources(ctx context.Context, postID uuid.UUID) ([]PostSource, error) {
	query := `SELECT id, source_url FROM sources WHERE post_id = $1`

	rows, err := r.pool.Query(ctx, query, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sources []PostSource
	for rows.Next() {
		var s PostSource
		if err := rows.Scan(&s.ID, &s.SourceURL); err != nil {
			return nil, err
		}
		sources = append(sources, s)
	}

	return sources, rows.Err()
}

func (r *PostRepository) GetUnseenPosts(ctx context.Context, userID, feedID uuid.UUID, limit int) ([]Post, error) {
	query := `
		SELECT p.id, p.created_at, p.feed_id, p.title, p.image_url,
		       p.media_objects, p.views, p.moderation_action, p.moderation_labels,
		       p.moderation_matched_entities
		FROM posts p
		WHERE p.feed_id = $1
		  AND NOT EXISTS (
		    SELECT 1 FROM posts_seen ps
		    WHERE ps.post_id = p.id AND ps.user_id = $2
		  )
		ORDER BY p.created_at DESC
		LIMIT $3`

	rows, err := r.pool.Query(ctx, query, feedID, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []Post
	for rows.Next() {
		var p Post
		var viewsJSON []byte
		if err := rows.Scan(
			&p.ID, &p.CreatedAt, &p.FeedID, &p.Title, &p.ImageURL,
			&p.MediaObjects, &viewsJSON, &p.ModerationAction, &p.ModerationLabels,
			&p.ModerationMatchedEntities,
		); err != nil {
			return nil, err
		}

		if viewsJSON != nil {
			json.Unmarshal(viewsJSON, &p.Views)
		}

		posts = append(posts, p)
	}

	return posts, rows.Err()
}

func (r *PostRepository) CountUnseenPosts(ctx context.Context, userID, feedID uuid.UUID) (int, error) {
	query := `
		SELECT COUNT(*)
		FROM posts p
		WHERE p.feed_id = $1
		  AND NOT EXISTS (
		    SELECT 1 FROM posts_seen ps
		    WHERE ps.post_id = p.id AND ps.user_id = $2
		  )`

	var count int
	err := r.pool.QueryRow(ctx, query, feedID, userID).Scan(&count)
	return count, err
}

func (r *PostRepository) CountByFeedID(ctx context.Context, feedID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM posts WHERE feed_id = $1`
	var count int
	err := r.pool.QueryRow(ctx, query, feedID).Scan(&count)
	return count, err
}

type CreatePostParams struct {
	ID           uuid.UUID
	FeedID       uuid.UUID
	Title        *string
	ImageURL     *string
	MediaObjects json.RawMessage
	Views        map[string]string
}

func (r *PostRepository) Create(ctx context.Context, params CreatePostParams) (*Post, error) {
	viewsJSON, err := json.Marshal(params.Views)
	if err != nil {
		return nil, err
	}

	query := `
		INSERT INTO posts (id, feed_id, title, image_url, media_objects, views)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at, feed_id, title, image_url, media_objects, views,
		          moderation_action, moderation_labels, moderation_matched_entities`

	var p Post
	var returnedViewsJSON []byte
	err = r.pool.QueryRow(ctx, query,
		params.ID, params.FeedID, params.Title, params.ImageURL, params.MediaObjects, viewsJSON,
	).Scan(
		&p.ID, &p.CreatedAt, &p.FeedID, &p.Title, &p.ImageURL,
		&p.MediaObjects, &returnedViewsJSON, &p.ModerationAction, &p.ModerationLabels,
		&p.ModerationMatchedEntities,
	)
	if err != nil {
		return nil, err
	}

	if returnedViewsJSON != nil {
		if err := json.Unmarshal(returnedViewsJSON, &p.Views); err != nil {
			return nil, err
		}
	}

	return &p, nil
}

func (r *PostRepository) CreateSource(ctx context.Context, postID uuid.UUID, sourceURL string) (*PostSource, error) {
	query := `
		INSERT INTO sources (id, post_id, source_url)
		VALUES ($1, $2, $3)
		RETURNING id, source_url`

	var s PostSource
	err := r.pool.QueryRow(ctx, query, uuid.New(), postID, sourceURL).Scan(&s.ID, &s.SourceURL)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *PostRepository) GetFeedPostsWithCursor(ctx context.Context, feedID uuid.UUID, limit int, cursor *string) ([]Post, error) {
	var query string
	var args []interface{}

	if cursor == nil || *cursor == "" {
		query = `
			SELECT p.id, p.created_at, p.feed_id, p.title, p.image_url,
			       p.media_objects, p.views, p.moderation_action, p.moderation_labels,
			       p.moderation_matched_entities
			FROM posts p
			WHERE p.feed_id = $1
			ORDER BY p.created_at DESC, p.id DESC
			LIMIT $2`
		args = []interface{}{feedID, limit}
	} else {
		cursorCreatedAt, cursorID, err := DecodeCursor(*cursor)
		if err != nil {
			return nil, err
		}

		query = `
			SELECT p.id, p.created_at, p.feed_id, p.title, p.image_url,
			       p.media_objects, p.views, p.moderation_action, p.moderation_labels,
			       p.moderation_matched_entities
			FROM posts p
			WHERE p.feed_id = $1
			  AND (p.created_at, p.id) < ($2, $3)
			ORDER BY p.created_at DESC, p.id DESC
			LIMIT $4`
		args = []interface{}{feedID, cursorCreatedAt, cursorID, limit}
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []Post
	for rows.Next() {
		var p Post
		var viewsJSON []byte
		if err := rows.Scan(
			&p.ID, &p.CreatedAt, &p.FeedID, &p.Title, &p.ImageURL,
			&p.MediaObjects, &viewsJSON, &p.ModerationAction, &p.ModerationLabels,
			&p.ModerationMatchedEntities,
		); err != nil {
			return nil, err
		}

		if viewsJSON != nil {
			if err := json.Unmarshal(viewsJSON, &p.Views); err != nil {
				return nil, err
			}
		}

		posts = append(posts, p)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i := range posts {
		sources, err := r.getPostSources(ctx, posts[i].ID)
		if err != nil {
			return nil, err
		}
		posts[i].Sources = sources
	}

	return posts, nil
}
