package app

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/consumer"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-processor/internal/services"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/db"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/nats"
	"github.com/MargoRSq/infatium-mono/services/go-processor/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-processor/repository"
	"github.com/rs/zerolog/log"
)

type App struct {
	cfg *config.Config

	dbPool       *db.Pool
	natsClient   *nats.Client
	consumer     *consumer.Consumer
	httpServer   *http.Server
	shutdownOTEL func(context.Context) error
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	observability.SetupLogger(a.cfg.OTELServiceName, a.cfg.Debug)

	log.Info().
		Str("service", a.cfg.OTELServiceName).
		Bool("consumer_enabled", a.cfg.NATSConsumerEnabled).
		Msg("Starting application")

	// Setup GlitchTip (Sentry-compatible)
	if a.cfg.GlitchTipDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:         a.cfg.GlitchTipDSN,
			Environment: a.cfg.Environment,
			Debug:       a.cfg.Debug,
			HTTPClient: &http.Client{
				Transport: &http.Transport{
					TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
				},
			},
		}); err != nil {
			log.Warn().Err(err).Msg("Failed to initialize GlitchTip")
		} else {
			log.Info().Msg("GlitchTip initialized")
			defer sentry.Flush(2 * time.Second)
		}
	}

	// Setup OpenTelemetry
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

	// Setup database pool
	pool, err := db.NewPool(ctx, a.cfg.DatabaseURL, int32(a.cfg.DatabasePoolMin), int32(a.cfg.DatabasePoolMax))
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	a.dbPool = pool

	// Setup NATS client
	natsClient, err := nats.NewClient(ctx, nats.ClientConfig{
		URL:  a.cfg.NATSUrl,
		Name: a.cfg.OTELServiceName,
	})
	if err != nil {
		return fmt.Errorf("create nats client: %w", err)
	}
	a.natsClient = natsClient

	// Create repositories
	promptRepo := repository.NewPromptRepository(pool.Pool)
	rawPostRepo := repository.NewRawPostRepository(pool.Pool)
	postRepo := repository.NewPostRepository(pool.Pool)
	feedRepo := repository.NewFeedRepository(pool.Pool)
	offsetRepo := repository.NewOffsetRepository(pool.Pool)

	// Create agents client
	agentsClient := clients.NewAgentsClient(a.cfg, natsClient)

	// Create publisher for WebSocket events
	publisher := nats.NewPublisher(natsClient.NC())

	// Create media warmer client (NATS RPC to go-poller)
	var mediaWarmerClient *clients.MediaWarmerClient
	if a.cfg.MediaWarmingEnabled {
		mediaWarmerClient = clients.NewMediaWarmerClient(natsClient.NC(), a.cfg.MediaWarmingTimeout)
		log.Info().Msg("Media warming client initialized")
	}

	// Create processing service
	processingService := services.NewFeedProcessingService(
		a.cfg,
		agentsClient,
		promptRepo,
		rawPostRepo,
		postRepo,
		feedRepo,
		offsetRepo,
		publisher,
		mediaWarmerClient,
	)

	// Start HTTP server early for health checks
	a.startHTTPServer()

	// Setup consumers
	if a.cfg.NATSConsumerEnabled {
		a.consumer = consumer.New(a.cfg, natsClient)

		// Raw posts consumer
		if err := a.consumer.SetupRawPostConsumer(ctx, func(ctx context.Context, event domain.RawPostCreatedEvent) error {
			return processingService.ProcessRawPostEvent(ctx, event)
		}); err != nil {
			return fmt.Errorf("setup raw post consumer: %w", err)
		}

		// Digest consumer
		if a.cfg.NATSDigestConsumerEnabled {
			if err := a.consumer.SetupDigestConsumer(ctx, func(ctx context.Context, event domain.DigestScheduledEvent) error {
				return processingService.ProcessDigestEvent(ctx, event)
			}); err != nil {
				return fmt.Errorf("setup digest consumer: %w", err)
			}
		}

		// Feed sync consumer
		if err := a.consumer.SetupFeedSyncConsumer(ctx, func(ctx context.Context, event domain.FeedInitialSyncEvent) error {
			return processingService.ProcessFeedInitialSyncEvent(ctx, event)
		}); err != nil {
			return fmt.Errorf("setup feed sync consumer: %w", err)
		}

		// Feed created consumer
		if err := a.consumer.SetupFeedCreatedConsumer(ctx, func(ctx context.Context, event domain.FeedCreatedEvent) error {
			return processingService.ProcessFeedCreatedEvent(ctx, event)
		}); err != nil {
			return fmt.Errorf("setup feed created consumer: %w", err)
		}
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

	if a.consumer != nil {
		a.consumer.Stop()
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
