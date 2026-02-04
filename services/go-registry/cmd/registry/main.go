package main

import (
	"context"
	"os"

	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/app"
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/config"
	"github.com/rs/zerolog/log"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to load configuration")
		os.Exit(1)
	}

	ctx := context.Background()

	application := app.New(cfg)

	if err := application.Run(ctx); err != nil {
		log.Fatal().Err(err).Msg("Application error")
		os.Exit(1)
	}
}
