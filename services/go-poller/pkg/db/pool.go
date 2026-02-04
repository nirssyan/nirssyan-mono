package db

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

type Pool struct {
	*pgxpool.Pool
}

func NewPool(ctx context.Context, databaseURL string, minConns, maxConns int32) (*Pool, error) {
	connString := databaseURL
	connString = strings.Replace(connString, "postgresql+psycopg://", "postgres://", 1)
	connString = strings.Replace(connString, "postgresql+asyncpg://", "postgres://", 1)
	connString = strings.Replace(connString, "postgresql://", "postgres://", 1)

	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}

	config.MinConns = minConns
	config.MaxConns = maxConns

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	log.Info().
		Str("host", config.ConnConfig.Host).
		Str("database", config.ConnConfig.Database).
		Int32("min_conns", minConns).
		Int32("max_conns", maxConns).
		Msg("Database pool connected")

	return &Pool{Pool: pool}, nil
}

func (p *Pool) Close() {
	p.Pool.Close()
	log.Info().Msg("Database pool closed")
}
