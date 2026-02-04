package db

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Session struct {
	pool *pgxpool.Pool
}

func NewSession(pool *Pool) *Session {
	return &Session{pool: pool.Pool}
}

func (s *Session) WithTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}

	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback(ctx)
			panic(p)
		}
	}()

	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}

	return tx.Commit(ctx)
}

func (s *Session) Exec(ctx context.Context, sql string, args ...interface{}) error {
	_, err := s.pool.Exec(ctx, sql, args...)
	return err
}

func (s *Session) Query(ctx context.Context, sql string, args ...interface{}) (pgx.Rows, error) {
	return s.pool.Query(ctx, sql, args...)
}

func (s *Session) QueryRow(ctx context.Context, sql string, args ...interface{}) pgx.Row {
	return s.pool.QueryRow(ctx, sql, args...)
}

func (s *Session) Pool() *pgxpool.Pool {
	return s.pool
}
