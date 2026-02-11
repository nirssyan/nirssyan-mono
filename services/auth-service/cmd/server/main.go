package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"

	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/config"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/handler"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/repository"
	"github.com/MargoRSq/infatium-mono/services/auth-service/internal/service"
)

func main() {
	logger := zerolog.New(os.Stdout).With().Timestamp().Logger()

	cfg, err := config.Load()
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to load config")
	}

	level, err := zerolog.ParseLevel(cfg.LogLevel)
	if err == nil {
		zerolog.SetGlobalLevel(level)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	cancel()
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to connect to database")
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		logger.Fatal().Err(err).Msg("failed to ping database")
	}
	logger.Info().Msg("connected to database")

	userRepo := repository.NewUserRepository(pool)
	tokenFamilyRepo := repository.NewTokenFamilyRepository(pool)
	refreshTokenRepo := repository.NewRefreshTokenRepository(pool)
	magicLinkRepo := repository.NewMagicLinkRepository(pool)

	jwtService := service.NewJWTService(cfg.JWTSecret, cfg.AccessTokenTTL)
	googleService := service.NewGoogleService(cfg.GoogleClientID)
	appleService := service.NewAppleService(cfg.AppleClientID, cfg.AppleTeamID, cfg.AppleKeyID)
	emailService := service.NewEmailService(cfg.ResendAPIKey, cfg.EmailFrom)

	authService := service.NewAuthService(
		userRepo,
		tokenFamilyRepo,
		refreshTokenRepo,
		magicLinkRepo,
		jwtService,
		googleService,
		appleService,
		emailService,
		cfg.RefreshTokenTTL,
		cfg.MagicLinkTTL,
		logger,
	)

	healthHandler := handler.NewHealthHandler(pool)
	authHandler := handler.NewAuthHandler(authService, logger)

	rateLimiters := middleware.NewEndpointRateLimiters(logger)

	r := chi.NewRouter()

	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.Timeout(30 * time.Second))
	r.Use(middleware.Logging(logger))
	r.Use(rateLimiters.Middleware)

	r.Get("/healthz", healthHandler.Healthz)
	r.Get("/readyz", healthHandler.Readyz)

	r.Route("/auth", func(r chi.Router) {
		r.Post("/google", authHandler.Google)
		r.Post("/apple", authHandler.Apple)
		r.Post("/magic-link", authHandler.MagicLink)
		r.Post("/verify", authHandler.Verify)
		r.Post("/refresh", authHandler.Refresh)
		r.Post("/logout", authHandler.Logout)
	})

	srv := &http.Server{
		Addr:         cfg.ServerAddr,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info().Str("addr", cfg.ServerAddr).Msg("starting server")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal().Err(err).Msg("server failed")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info().Msg("shutting down server...")

	ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error().Err(err).Msg("server forced to shutdown")
	}

	logger.Info().Msg("server stopped")
}
