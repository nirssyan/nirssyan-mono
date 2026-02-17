package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
)

type HealthHandler struct {
	pool   *pgxpool.Pool
	logger zerolog.Logger
}

func NewHealthHandler(pool *pgxpool.Pool, logger zerolog.Logger) *HealthHandler {
	return &HealthHandler{pool: pool, logger: logger}
}

func (h *HealthHandler) Healthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (h *HealthHandler) Readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	if err := h.pool.Ping(ctx); err != nil {
		stat := h.pool.Stat()
		h.logger.Warn().
			Err(err).
			Int32("total_conns", stat.TotalConns()).
			Int32("idle_conns", stat.IdleConns()).
			Int32("acquired_conns", stat.AcquiredConns()).
			Msg("readyz: pool ping failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "error",
			"error":  err.Error(),
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
