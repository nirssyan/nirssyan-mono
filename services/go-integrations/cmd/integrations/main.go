package main

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
	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/handlers"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/logging"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/otel"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/services"
)

var Version = "dev"

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	logging.Setup(cfg.OTelServiceName, cfg.Debug)

	log.Info().
		Str("version", Version).
		Bool("debug", cfg.Debug).
		Msg("Starting makefeed-integrations-go")

	if cfg.GlitchTipDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:         cfg.GlitchTipDSN,
			Environment: cfg.Environment,
			Debug:       cfg.Debug,
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

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	shutdownTracing, err := otel.InitTracing(ctx, cfg)
	if err != nil {
		log.Error().Err(err).Msg("Failed to initialize tracing")
	}
	defer shutdownTracing()

	otel.StartMetricsServer(cfg.MetricsPort)

	app := fiber.New(fiber.Config{
		DisableStartupMessage: true,
		ReadTimeout:          30 * time.Second,
		WriteTimeout:         30 * time.Second,
		IdleTimeout:          120 * time.Second,
	})

	app.Use(middleware.Recovery())
	app.Use(middleware.RequestID())
	app.Use(middleware.Logging())

	appStoreService := services.NewAppStoreService(cfg)
	sentryService := services.NewSentryService(cfg)
	glitchTipService := services.NewGlitchTipService(cfg)

	appStoreHandler := handlers.NewAppStoreHandler(appStoreService)
	sentryHandler := handlers.NewSentryHandler(sentryService)
	glitchTipHandler := handlers.NewGlitchTipHandler(glitchTipService)

	app.Get("/healthz", handlers.HealthCheck)
	app.Post("/webhooks/appstore/notifications", appStoreHandler.HandleNotification)
	app.Post("/webhooks/sentry/notifications", sentryHandler.HandleNotification)
	app.Post("/webhooks/glitchtip/notifications", glitchTipHandler.HandleNotification)

	go func() {
		addr := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)
		log.Info().Str("addr", addr).Msg("Server listening")
		if err := app.Listen(addr); err != nil {
			log.Error().Err(err).Msg("Server error")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("Shutting down server...")

	if err := app.ShutdownWithTimeout(30 * time.Second); err != nil {
		log.Error().Err(err).Msg("Server forced to shutdown")
	}

	log.Info().Msg("Server stopped")
}
