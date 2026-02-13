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
	sentryhttp "github.com/getsentry/sentry-go/http"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/handlers"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/websocket"
	"github.com/MargoRSq/infatium-mono/services/go-api/pkg/db"
	"github.com/MargoRSq/infatium-mono/services/go-api/pkg/observability"
	"github.com/MargoRSq/infatium-mono/services/go-api/pkg/storage"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
)

type App struct {
	cfg *config.Config

	dbPool               *db.Pool
	natsConn             *nats.Conn
	httpServer           *http.Server
	shutdownOTEL         func(context.Context) error
	wsManager            *websocket.Manager
	notificationConsumer *websocket.NotificationConsumer
}

func New(cfg *config.Config) *App {
	return &App{cfg: cfg}
}

func (a *App) Run(ctx context.Context) error {
	observability.SetupLogger(a.cfg.OTELServiceName, a.cfg.Debug)

	log.Info().
		Str("service", a.cfg.OTELServiceName).
		Msg("Starting application")

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

	if a.cfg.OTELEnabled {
		shutdown, err := observability.SetupOTEL(
			ctx,
			a.cfg.OTELServiceName,
			a.cfg.OTELExporterEndpoint,
			a.cfg.OTELEnvironment,
		)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to setup OpenTelemetry")
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

	nc, err := nats.Connect(a.cfg.NATSURL)
	if err != nil {
		return fmt.Errorf("connect to NATS: %w", err)
	}
	a.natsConn = nc
	log.Info().Str("url", a.cfg.NATSURL).Msg("Connected to NATS")

	a.wsManager = websocket.NewManager()
	a.notificationConsumer = websocket.NewNotificationConsumer(a.wsManager, nc)
	if err := a.notificationConsumer.Start(ctx); err != nil {
		log.Warn().Err(err).Msg("Failed to start notification consumer")
	}

	var s3Client *storage.S3Client
	if a.cfg.S3Endpoint != "" {
		s3Client, err = storage.NewS3Client(a.cfg.S3Endpoint, a.cfg.S3AccessKey, a.cfg.S3SecretKey, a.cfg.S3UseSSL)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to initialize S3 client, image uploads disabled")
		} else {
			log.Info().Msg("S3 client initialized")
		}
	}

	agentsClient := clients.NewAgentsClient(nc)
	telegramClient := clients.NewTelegramClient(nc, a.cfg.TelegramBotToken)
	validationClient := clients.NewValidationClient(nc)
	adminNotifyClient := clients.NewAdminNotifyClient(
		a.cfg.FeedbackTelegramBotToken,
		a.cfg.FeedbackTelegramChatID,
		a.cfg.Environment,
	)

	var ruStoreClient *clients.RuStoreClient
	if a.cfg.RuStoreKeyID != "" {
		var err error
		ruStoreClient, err = clients.NewRuStoreClient(a.cfg.RuStoreKeyID, a.cfg.RuStorePrivateKeyPath, a.cfg.RuStorePrivateKey)
		if err != nil {
			log.Warn().Err(err).Msg("Failed to initialize RuStore client")
		} else {
			log.Info().Msg("RuStore client initialized")
		}
	}

	feedRepo := repository.NewFeedRepository(pool.Pool)
	postRepo := repository.NewPostRepository(pool.Pool)
	postSeenRepo := repository.NewPostSeenRepository(pool.Pool)
	userRepo := repository.NewUserRepository(pool.Pool)
	usersFeedRepo := repository.NewUsersFeedRepository(pool.Pool)
	subscriptionRepo := repository.NewSubscriptionRepository(pool.Pool)
	marketplaceRepo := repository.NewMarketplaceRepository(pool.Pool)
	deviceTokenRepo := repository.NewDeviceTokenRepository(pool.Pool)
	feedbackRepo := repository.NewFeedbackRepository(pool.Pool)
	suggestionRepo := repository.NewSuggestionRepository(pool.Pool)
	tagRepo := repository.NewTagRepository(pool.Pool)
	userTagRepo := repository.NewUserTagRepository(pool.Pool)
	telegramUserRepo := repository.NewTelegramUserRepository(pool.Pool)
	telegramLinkCodeRepo := repository.NewTelegramLinkCodeRepository(pool.Pool)
	promptRepo := repository.NewPromptRepository(pool.Pool)
	prePromptRepo := repository.NewPrePromptRepository(pool.Pool)
	rawFeedRepo := repository.NewRawFeedRepository(pool.Pool)
	rawPostRepo := repository.NewRawPostRepository(pool.Pool)

	feedHandler := handlers.NewFeedHandler(
		feedRepo, postRepo, postSeenRepo, usersFeedRepo,
		promptRepo, prePromptRepo, rawFeedRepo, rawPostRepo, subscriptionRepo, userRepo,
		suggestionRepo, agentsClient, validationClient, telegramClient, adminNotifyClient,
		a.cfg.AdminTelegramFeedThreadID, nc,
	)
	feedViewHandler := handlers.NewFeedViewHandler(feedRepo, postRepo, rawFeedRepo, agentsClient)
	postHandler := handlers.NewPostHandler(feedRepo, postRepo, postSeenRepo)
	userHandler := handlers.NewUserHandler(userRepo, adminNotifyClient, a.cfg.AdminTelegramUserThreadID)
	subscriptionHandler := handlers.NewSubscriptionHandler(subscriptionRepo, usersFeedRepo, ruStoreClient)
	marketplaceHandler := handlers.NewMarketplaceHandler(marketplaceRepo, validationClient)
	deviceTokenHandler := handlers.NewDeviceTokenHandler(deviceTokenRepo)
	usersFeedHandler := handlers.NewUsersFeedHandler(usersFeedRepo, feedRepo)
	feedbackHandler := handlers.NewFeedbackHandler(
		feedbackRepo, userRepo, usersFeedRepo, s3Client,
		a.cfg.FeedbackTelegramBotToken, a.cfg.FeedbackTelegramChatID,
		a.cfg.FeedbackTelegramThreadID, a.cfg.S3Bucket, a.cfg.S3PublicURL,
	)
	suggestionsHandler := handlers.NewSuggestionsHandler(suggestionRepo)
	tagsHandler := handlers.NewTagsHandler(tagRepo, userTagRepo)
	mediaHandler := handlers.NewMediaHandler(telegramClient, a.cfg.S3PublicURL, a.cfg.MediaProxyTimeout, pool.Pool, s3Client, a.cfg.S3Bucket)
	sourceValidationHandler := handlers.NewSourceValidationHandler(validationClient)
	telegramLinkHandler := handlers.NewTelegramLinkHandler(telegramUserRepo, telegramLinkCodeRepo, a.cfg.TelegramBotUsername, a.cfg.TelegramLinkExpiryMins)
	telegramSyncHandler := handlers.NewTelegramSyncHandler(telegramClient)
	healthHandler := handlers.NewHealthHandler(pool.Pool)
	wsHandler := websocket.NewHandler(a.wsManager, a.cfg.JWTSecret)

	authMiddleware := middleware.NewAuthMiddleware(a.cfg.JWTSecret)

	router := chi.NewRouter()

	router.Use(sentryhttp.New(sentryhttp.Options{Repanic: true}).Handle)
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins:   a.cfg.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           300,
	}))
	router.Use(middleware.RequestID)
	router.Use(middleware.Logging)

	router.Get("/healthz", healthHandler.Healthz)
	router.Get("/readyz", healthHandler.Readyz)
	router.Handle("/metrics", observability.MetricsHandler())

	router.Get("/ws/feeds", wsHandler.HandleFeedNotifications)

	router.Mount("/marketplace", marketplaceHandler.Routes(authMiddleware.Authenticate))
	router.Mount("/suggestions", suggestionsHandler.Routes())
	router.Mount("/tags", tagsHandler.Routes())
	router.Mount("/media", mediaHandler.Routes())
	router.Mount("/sources", sourceValidationHandler.Routes())
	router.Mount("/telegram", telegramLinkHandler.Routes())
	router.Get("/share/posts/{post_id}", postHandler.GetPostPublic)

	adminMiddleware := middleware.NewAdminMiddleware(userRepo)
	adminHandler := handlers.NewAdminHandler(suggestionRepo, tagRepo, marketplaceRepo)

	router.Group(func(r chi.Router) {
		r.Use(authMiddleware.Authenticate)

		r.Mount("/feeds", feedHandler.Routes())
		r.Mount("/modal", feedViewHandler.Routes())
		r.Mount("/posts", postHandler.Routes())
		r.Mount("/users", userHandler.Routes())
		r.Mount("/subscriptions", subscriptionHandler.Routes())
		r.Mount("/device-tokens", deviceTokenHandler.Routes())
		r.Mount("/users_feeds", usersFeedHandler.Routes())
		r.Mount("/feedback", feedbackHandler.Routes())
		r.Mount("/users/tags", tagsHandler.AuthenticatedRoutes())
		r.Mount("/telegram/auth", telegramLinkHandler.AuthenticatedRoutes())
		r.Mount("/sync", telegramSyncHandler.Routes())

		r.Route("/admin", func(r chi.Router) {
			r.Use(adminMiddleware.RequireAdmin)
			r.Mount("/users", userHandler.AdminRoutes())
			r.Mount("/", adminHandler.Routes())
		})
	})

	a.httpServer = &http.Server{
		Addr:         fmt.Sprintf(":%d", a.cfg.HTTPPort),
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
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

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if a.httpServer != nil {
		if err := a.httpServer.Shutdown(shutdownCtx); err != nil {
			log.Error().Err(err).Msg("HTTP server shutdown error")
		}
	}

	if a.notificationConsumer != nil {
		a.notificationConsumer.Stop()
	}

	if a.natsConn != nil {
		a.natsConn.Close()
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
