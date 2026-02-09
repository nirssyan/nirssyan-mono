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
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/services"
	"github.com/MargoRSq/infatium-mono/services/go-registry/pkg/db"
	"github.com/MargoRSq/infatium-mono/services/go-registry/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-registry/repository"
	"github.com/rs/zerolog/log"
)

type App struct {
	cfg *config.Config

	dbPool         *db.Pool
	llmSyncService *services.LLMSyncService
	httpServer     *http.Server
	shutdownOTEL   func(context.Context) error
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	observability.SetupLogger(a.cfg.OTELServiceName, a.cfg.Debug)

	log.Info().
		Str("service", a.cfg.OTELServiceName).
		Bool("llm_sync_enabled", a.cfg.LLMModelsSyncEnabled).
		Bool("registry_sync_enabled", a.cfg.RegistrySyncEnabled).
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

	// Create clients
	openRouterClient := clients.NewOpenRouterClient(a.cfg.OpenRouterAPIKey)
	telegramClient := clients.NewTelegramClient(
		a.cfg.TelegramBotToken,
		a.cfg.TelegramChatID,
		a.cfg.TelegramThreadID,
	)

	// Create repositories
	llmModelsRepo := repository.NewLLMModelsRepository(pool.Pool)

	// Create and start services
	a.llmSyncService = services.NewLLMSyncService(
		a.cfg,
		openRouterClient,
		telegramClient,
		llmModelsRepo,
	)

	// Start HTTP server for health checks
	a.startHTTPServer()

	// Start sync services
	a.llmSyncService.Start(ctx)

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

	if a.llmSyncService != nil {
		a.llmSyncService.Stop()
	}

	if a.httpServer != nil {
		if err := a.httpServer.Shutdown(shutdownCtx); err != nil {
			log.Error().Err(err).Msg("HTTP server shutdown error")
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
