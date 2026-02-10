package app

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-rss-api/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-rss-api/internal/handlers"
	"github.com/MargoRSq/infatium-mono/services/go-rss-api/repository"
)

type App struct {
	cfg        *config.Config
	pool       *pgxpool.Pool
	httpServer *http.Server
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Info().Msg("Starting go-rss-api")

	pool, err := pgxpool.New(ctx, a.cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("ping database: %w", err)
	}
	a.pool = pool
	log.Info().Msg("Connected to database")

	catalogRepo := repository.NewCatalogRepository(pool)
	subscriptionRepo := repository.NewSubscriptionRepository(pool)
	postRepo := repository.NewPostRepository(pool)

	healthHandler := handlers.NewHealthHandler()
	rssHandler := handlers.NewRSSHandler(catalogRepo, subscriptionRepo, postRepo)

	router := chi.NewRouter()
	router.Get("/healthz", healthHandler.Healthz)
	router.Get("/vendors", rssHandler.GetVendors)
	router.Get("/vendors/{vendor_id}/models", rssHandler.GetModels)
	router.Get("/rss/{vendor}/{model}", rssHandler.GetRSSByVendorModel)
	router.Head("/rss/{vendor}/{model}", rssHandler.GetRSSByVendorModel)
	router.Get("/rss/{slug}", rssHandler.GetRSSBySlug)
	router.Head("/rss/{slug}", rssHandler.GetRSSBySlug)

	a.httpServer = &http.Server{
		Addr:         fmt.Sprintf(":%d", a.cfg.HTTPPort),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Info().Int("port", a.cfg.HTTPPort).Msg("HTTP server started")
		if err := a.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("HTTP server error")
		}
	}()

	a.waitForShutdown(ctx)
	return nil
}

func (a *App) waitForShutdown(ctx context.Context) {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigChan:
		log.Info().Str("signal", sig.String()).Msg("Shutdown signal received")
	case <-ctx.Done():
		log.Info().Msg("Context cancelled")
	}

	a.shutdown()
}

func (a *App) shutdown() {
	log.Info().Msg("Starting graceful shutdown")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if a.httpServer != nil {
		if err := a.httpServer.Shutdown(shutdownCtx); err != nil {
			log.Error().Err(err).Msg("HTTP server shutdown error")
		}
	}

	if a.pool != nil {
		a.pool.Close()
	}

	log.Info().Msg("Graceful shutdown complete")
}
