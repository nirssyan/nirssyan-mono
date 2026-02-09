package app

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/rss"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/telegram"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/validation"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/web"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/db"
	pollerhttp "github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/moderation"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/storage"
	"github.com/MargoRSq/infatium-mono/services/go-poller/repository"
	"github.com/rs/zerolog/log"
)

type App struct {
	cfg *config.Config

	dbPool     *db.Pool
	natsClient *nats.Client

	rssPoller      *rss.Poller
	webPoller      *web.Poller
	telegramPoller *telegram.Poller
	telegramClient *telegram.Client

	httpServer *http.Server

	shutdownOTEL func(context.Context) error
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	observability.SetupLogger(a.cfg.OTELServiceName, a.cfg.Debug)

	log.Info().
		Str("service", a.cfg.OTELServiceName).
		Bool("rss_enabled", a.cfg.RSSPollingEnabled).
		Bool("web_enabled", a.cfg.WebPollingEnabled).
		Bool("telegram_enabled", a.cfg.TelegramPollingEnabled).
		Msg("Starting application")

	if a.cfg.OTELEnabled {
		shutdown, err := observability.SetupOTEL(
			ctx,
			a.cfg.OTELServiceName,
			a.cfg.OTELExporterEndpoint,
			a.cfg.OTELEnvironment,
		)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to setup OpenTelemetry, continuing without tracing")
		} else {
			a.shutdownOTEL = shutdown
			log.Info().Str("endpoint", a.cfg.OTELExporterEndpoint).Msg("OpenTelemetry initialized")
		}
	}

	pool, err := db.NewPool(ctx, a.cfg.DatabaseURL, int32(a.cfg.DatabasePoolMin), int32(a.cfg.DatabasePoolMax))
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	a.dbPool = pool

	natsClient, err := nats.NewClient(ctx, nats.ClientConfig{
		URL:  a.cfg.NATSUrl,
		Name: a.cfg.OTELServiceName,
	})
	if err != nil {
		return fmt.Errorf("create nats client: %w", err)
	}
	a.natsClient = natsClient

	if a.cfg.NATSPublishEnabled {
		if _, err := natsClient.EnsureStream(ctx, "posts", []string{"posts.new.*"}); err != nil {
			log.Warn().Err(err).Msg("Failed to ensure NATS stream, publishing may fail")
		}
	}

	rawFeedRepo := repository.NewRawFeedRepository(pool.Pool)
	rawPostRepo := repository.NewRawPostRepository(pool.Pool)

	natsPublisher := nats.NewPublisher(natsClient, a.cfg.NATSPublishEnabled)

	var moderationClient *moderation.Client
	if a.cfg.ModerationServiceURL != "" {
		moderationClient = moderation.NewClient(a.cfg.ModerationServiceURL)
	}

	// Start HTTP server early for health checks
	a.startHTTPServer()

	httpClient := pollerhttp.NewClient(pollerhttp.ClientConfig{
		Timeout:        a.cfg.ScrapingTimeout,
		MaxRetries:     a.cfg.ScrapingMaxRetries,
		CacheEnabled:   a.cfg.HTTPCacheEnabled,
		CacheTTLHours:  a.cfg.HTTPCacheTTLHours,
		RequestsPerSec: a.cfg.ScrapingRequestsPerSec,
	})

	var rssParser *rss.Parser
	if a.cfg.RSSPollingEnabled {
		rssParser = rss.NewParser(httpClient)
		contentEnricher := rss.NewContentEnricher(httpClient, a.cfg.RSSMinContentLength)

		a.rssPoller = rss.NewPoller(
			a.cfg,
			rssParser,
			contentEnricher,
			rawFeedRepo,
			rawPostRepo,
			natsPublisher,
			moderationClient,
		)
	}

	if a.cfg.WebPollingEnabled {
		a.webPoller = web.NewPoller(
			a.cfg,
			httpClient,
			rawFeedRepo,
			rawPostRepo,
			natsPublisher,
			moderationClient,
		)
	}

	if a.cfg.TelegramPollingEnabled {
		log.Info().
			Int("api_id", a.cfg.TelegramAPIID).
			Str("api_hash_len", fmt.Sprintf("%d", len(a.cfg.TelegramAPIHash))).
			Str("workdir", a.cfg.TelegramWorkdir).
			Str("session_name", a.cfg.TelegramSessionName).
			Msg("Initializing Telegram client")

		telegramClient := telegram.NewClient(a.cfg, log.Logger)
		a.telegramClient = telegramClient

		log.Info().Msg("Telegram client created, connecting...")

		if err := telegramClient.Connect(ctx); err != nil {
			log.Error().Err(err).Msg("Failed to connect Telegram client, Telegram polling disabled")
		} else {
			var mediaWarmer *telegram.MediaWarmer
			if a.cfg.MediaWarmingEnabled && a.cfg.S3Endpoint != "" {
				s3Client, err := storage.NewS3Client(a.cfg.S3Endpoint, a.cfg.S3AccessKey, a.cfg.S3SecretKey, a.cfg.S3UseSSL)
				if err != nil {
					log.Warn().Err(err).Msg("Failed to initialize S3 client for media warming")
				} else {
					mediaWarmer = telegram.NewMediaWarmer(a.cfg, telegramClient, s3Client, a.dbPool.Pool)
					if err := mediaWarmer.Register(natsClient.NC()); err != nil {
						log.Warn().Err(err).Msg("Failed to register media warm NATS handler")
					} else {
						log.Info().
							Float64("rate_per_sec", a.cfg.MediaWarmingRatePerSec).
							Int("concurrency", a.cfg.MediaWarmingConcurrency).
							Msg("Media warming initialized")
					}
				}
			}

			a.telegramPoller = telegram.NewPoller(
				a.cfg,
				telegramClient,
				rawFeedRepo,
				rawPostRepo,
				natsPublisher,
				moderationClient,
				mediaWarmer,
			)
		}
	}

	if a.cfg.NATSValidationHandlerEnabled {
		validationHandler := validation.NewHandler(httpClient, rssParser, a.telegramClient)
		if err := validationHandler.Register(natsClient.NC()); err != nil {
			log.Warn().Err(err).Msg("Failed to register unified source validation handler")
		}
	}

	if a.telegramClient != nil && a.telegramClient.IsConnected() {
		fileHandler := telegram.NewFileHandler(a.telegramClient, a.dbPool.Pool)
		if err := fileHandler.Register(natsClient.NC()); err != nil {
			log.Warn().Err(err).Msg("Failed to register Telegram file handler")
		}
	}

	if a.telegramPoller != nil {
		syncHandler := telegram.NewSyncHandler(a.telegramPoller)
		if err := syncHandler.Register(natsClient.NC()); err != nil {
			log.Warn().Err(err).Msg("Failed to register Telegram sync handler")
		}
	}

	if a.rssPoller != nil {
		a.rssPoller.Start(ctx)
	}

	if a.webPoller != nil {
		a.webPoller.Start(ctx)
	}

	if a.telegramPoller != nil {
		a.telegramPoller.Start(ctx)
	}

	a.waitForShutdown(ctx)

	return nil
}

func (a *App) startHTTPServer() {
	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if a.dbPool == nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte("Database not ready"))
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		if err := a.dbPool.Ping(ctx); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte("Database ping failed"))
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	mux.Handle("/metrics", observability.MetricsHandler())

	a.httpServer = &http.Server{
		Addr:         fmt.Sprintf(":%d", a.cfg.HTTPPort),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	go func() {
		log.Info().Int("port", a.cfg.HTTPPort).Msg("HTTP server started")
		if err := a.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("HTTP server error")
		}
	}()
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

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if a.rssPoller != nil {
		a.rssPoller.Stop()
	}

	if a.webPoller != nil {
		a.webPoller.Stop()
	}

	if a.telegramPoller != nil {
		a.telegramPoller.Stop()
	}

	if a.telegramClient != nil {
		if err := a.telegramClient.Close(); err != nil {
			log.Error().Err(err).Msg("Telegram client close error")
		}
	}

	if a.httpServer != nil {
		if err := a.httpServer.Shutdown(shutdownCtx); err != nil {
			log.Error().Err(err).Msg("HTTP server shutdown error")
		}
	}

	if a.natsClient != nil {
		if err := a.natsClient.Close(); err != nil {
			log.Error().Err(err).Msg("NATS client close error")
		}
	}

	if a.dbPool != nil {
		a.dbPool.Close()
	}

	if a.shutdownOTEL != nil {
		if err := a.shutdownOTEL(shutdownCtx); err != nil {
			log.Error().Err(err).Msg("OTEL shutdown error")
		}
	}

	log.Info().Msg("Graceful shutdown complete")
}
