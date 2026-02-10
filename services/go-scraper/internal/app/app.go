package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/aucjp_client"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/scrapers"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/internal/scrapers/aucjp"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/pkg/db"
	"github.com/MargoRSq/infatium-mono/services/go-scraper/repository"
)

type App struct {
	cfg    *config.Config
	dbPool *db.Pool
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	log.Info().Msg("Starting go-scraper")

	pool, err := db.NewPool(ctx, a.cfg.DatabaseURL, int32(a.cfg.DatabasePoolMin), int32(a.cfg.DatabasePoolMax))
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	a.dbPool = pool

	httpClient := aucjp_client.New()

	catalogRepo := repository.NewCatalogRepository(pool.Pool)
	subRepo := repository.NewSubscriptionRepository(pool.Pool)
	postRepo := repository.NewPostRepository(pool.Pool)

	registry := scrapers.NewRegistry()
	registry.Register(aucjp.New(httpClient, catalogRepo))

	for _, s := range registry.All() {
		log.Info().Str("scraper", s.Name()).Msg("Running initial catalog sync")
		if err := s.SyncCatalog(ctx); err != nil {
			log.Warn().Err(err).Str("scraper", s.Name()).Msg("Initial catalog sync failed")
		}
	}

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	go a.runLoop(ctx, registry, subRepo, postRepo)

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigChan:
		log.Info().Str("signal", sig.String()).Msg("Shutdown signal received")
	case <-ctx.Done():
		log.Info().Msg("Context cancelled")
	}

	cancel()
	a.shutdown()
	return nil
}

func (a *App) runLoop(ctx context.Context, registry *scrapers.Registry, subRepo *repository.SubscriptionRepository, postRepo *repository.PostRepository) {
	ticker := time.NewTicker(a.cfg.ScrapeInterval)
	defer ticker.Stop()

	a.scrapeAll(ctx, registry, subRepo, postRepo)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			a.scrapeAll(ctx, registry, subRepo, postRepo)
		}
	}
}

func (a *App) scrapeAll(ctx context.Context, registry *scrapers.Registry, subRepo *repository.SubscriptionRepository, postRepo *repository.PostRepository) {
	subs, err := subRepo.GetActive(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get active subscriptions")
		return
	}

	if len(subs) == 0 {
		log.Debug().Msg("No active subscriptions")
		return
	}

	log.Info().Int("subscriptions", len(subs)).Msg("Starting scrape cycle")

	for _, sub := range subs {
		scraper, ok := registry.Get("aucjp")
		if !ok {
			log.Warn().Str("sub_id", sub.ID).Msg("No aucjp scraper registered")
			continue
		}

		scraperSub := &scrapers.Subscription{
			ID:            sub.ID,
			VendorID:      sub.VendorID,
			ModelName:     sub.ModelName,
			LastScrapedAt: sub.LastScrapedAt,
		}

		posts, err := scraper.Scrape(ctx, scraperSub)
		if err != nil {
			log.Error().Err(err).
				Int("vendor_id", sub.VendorID).
				Str("model", sub.ModelName).
				Msg("Scrape failed")
			continue
		}

		postRows := make([]repository.PostRow, len(posts))
		for i, p := range posts {
			postRows[i] = repository.PostRow{
				VendorID:    sub.VendorID,
				ModelName:   sub.ModelName,
				Hash:        p.Hash,
				Title:       p.Title,
				Description: p.Description,
				Link:        p.Link,
				PubDate:     p.PubDate,
				Extra:       p.Extra,
			}
		}

		inserted, err := postRepo.UpsertPosts(ctx, sub.VendorID, sub.ModelName, postRows)
		if err != nil {
			log.Error().Err(err).Str("sub_id", sub.ID).Msg("Failed to upsert posts")
			continue
		}

		if err := postRepo.CleanupOld(ctx, sub.VendorID, sub.ModelName, 500); err != nil {
			log.Error().Err(err).Str("sub_id", sub.ID).Msg("Failed to cleanup old posts")
		}

		if err := subRepo.UpdateLastScraped(ctx, sub.ID, time.Now()); err != nil {
			log.Error().Err(err).Str("sub_id", sub.ID).Msg("Failed to update last_scraped_at")
		}

		log.Info().
			Int("vendor_id", sub.VendorID).
			Str("model", sub.ModelName).
			Int("total", len(posts)).
			Int("new", inserted).
			Msg("Scrape cycle complete for subscription")
	}
}

func (a *App) shutdown() {
	log.Info().Msg("Starting graceful shutdown")

	if a.dbPool != nil {
		a.dbPool.Close()
	}

	log.Info().Msg("Graceful shutdown complete")
}
