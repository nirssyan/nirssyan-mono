package services

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-registry/internal/config"
	"github.com/MargoRSq/infatium-mono/services/go-registry/repository"
	"github.com/rs/zerolog/log"
	"github.com/shopspring/decimal"
)

const MinPriceChangePercent = 0.001

// LLMSyncService syncs LLM models from OpenRouter API
type LLMSyncService struct {
	cfg            *config.Config
	openRouter     *clients.OpenRouterClient
	telegram       *clients.TelegramClient
	repo           *repository.LLMModelsRepository
	running        bool
	stopCh         chan struct{}
}

func NewLLMSyncService(
	cfg *config.Config,
	openRouter *clients.OpenRouterClient,
	telegram *clients.TelegramClient,
	repo *repository.LLMModelsRepository,
) *LLMSyncService {
	return &LLMSyncService{
		cfg:        cfg,
		openRouter: openRouter,
		telegram:   telegram,
		repo:       repo,
		stopCh:     make(chan struct{}),
	}
}

// Start begins the sync polling loop
func (s *LLMSyncService) Start(ctx context.Context) {
	if !s.cfg.LLMModelsSyncEnabled {
		log.Info().Msg("LLM models sync disabled")
		return
	}

	s.running = true
	log.Info().
		Dur("interval", s.cfg.LLMModelsSyncInterval).
		Msg("LLM models sync service started")

	go s.pollingLoop(ctx)
}

// Stop stops the sync service
func (s *LLMSyncService) Stop() {
	if !s.running {
		return
	}
	close(s.stopCh)
	s.running = false
	log.Info().Msg("LLM models sync service stopped")
}

func (s *LLMSyncService) pollingLoop(ctx context.Context) {
	// Sync immediately on start
	if err := s.Sync(ctx); err != nil {
		log.Error().Err(err).Msg("Initial LLM models sync failed")
	}

	ticker := time.NewTicker(s.cfg.LLMModelsSyncInterval)
	defer ticker.Stop()

	for {
		select {
		case <-s.stopCh:
			return
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := s.Sync(ctx); err != nil {
				log.Error().Err(err).Msg("LLM models sync failed")
			}
		}
	}
}

// Sync performs a single sync operation
func (s *LLMSyncService) Sync(ctx context.Context) error {
	log.Info().Msg("Starting LLM models sync")
	start := time.Now()

	// Fetch models from API
	apiModels, err := s.openRouter.FetchModels(ctx)
	if err != nil {
		return err
	}

	// Get existing model IDs
	existingIDs, err := s.repo.GetAllModelIDs(ctx)
	if err != nil {
		return err
	}

	var newModels []clients.ParsedModel
	var priceChanges []clients.PriceChange

	for _, model := range apiModels {
		if _, exists := existingIDs[model.ModelID]; exists {
			// Check for price changes
			change, err := s.checkAndUpdatePrices(ctx, model)
			if err != nil {
				log.Warn().Err(err).Str("model_id", model.ModelID).Msg("Failed to check prices")
				continue
			}
			if change != nil {
				priceChanges = append(priceChanges, *change)
			}
		} else {
			// Insert new model
			dbModel := &repository.LLMModel{
				ID:              uuid.New(),
				ModelID:         model.ModelID,
				Name:            model.Name,
				ContextLength:   model.ContextLen,
				PricePrompt:     model.PricePrompt,
				PriceCompletion: model.PriceCompletion,
				ModelCreatedAt:  model.ModelCreatedAt,
				CreatedAt:       time.Now(),
			}
			if err := s.repo.InsertModel(ctx, dbModel); err != nil {
				log.Warn().Err(err).Str("model_id", model.ModelID).Msg("Failed to insert model")
				continue
			}
			newModels = append(newModels, model)
			log.Debug().Str("model_id", model.ModelID).Msg("Inserted new model")
		}
	}

	duration := time.Since(start)
	log.Info().
		Int("new_models", len(newModels)).
		Int("price_changes", len(priceChanges)).
		Int("total_synced", len(apiModels)).
		Dur("duration", duration).
		Msg("LLM models sync complete")

	// Send notifications
	if len(newModels) > 0 {
		if err := s.telegram.NotifyNewModels(ctx, newModels); err != nil {
			log.Error().Err(err).Msg("Failed to send new models notification")
		}
	}

	if len(priceChanges) > 0 {
		if err := s.telegram.NotifyPriceChanges(ctx, priceChanges); err != nil {
			log.Error().Err(err).Msg("Failed to send price changes notification")
		}
	}

	return nil
}

func (s *LLMSyncService) checkAndUpdatePrices(ctx context.Context, model clients.ParsedModel) (*clients.PriceChange, error) {
	existing, err := s.repo.GetModelByID(ctx, model.ModelID)
	if err != nil || existing == nil {
		return nil, err
	}

	promptChanged := !existing.PricePrompt.Equal(model.PricePrompt)
	completionChanged := !existing.PriceCompletion.Equal(model.PriceCompletion)

	if !promptChanged && !completionChanged {
		// Just update last_synced_at
		return nil, s.repo.UpdateLastSyncedAt(ctx, model.ModelID)
	}

	// Calculate percent changes
	percentPrompt := calcPercentChange(existing.PricePrompt, model.PricePrompt)
	percentCompletion := calcPercentChange(existing.PriceCompletion, model.PriceCompletion)

	// Update prices in DB
	if err := s.repo.UpdateModelPrices(
		ctx,
		existing.ID,
		model.ModelID,
		existing.PricePrompt,
		existing.PriceCompletion,
		model.PricePrompt,
		model.PriceCompletion,
	); err != nil {
		return nil, err
	}

	// Check if change is significant enough to notify
	significantPrompt := percentPrompt != nil && math.Abs(*percentPrompt) >= MinPriceChangePercent
	significantCompletion := percentCompletion != nil && math.Abs(*percentCompletion) >= MinPriceChangePercent

	if !significantPrompt && !significantCompletion {
		log.Debug().
			Str("model_id", model.ModelID).
			Msg("Price change below threshold, skipping notification")
		return nil, nil
	}

	log.Info().
		Str("model_id", model.ModelID).
		Str("old_prompt", existing.PricePrompt.String()).
		Str("new_prompt", model.PricePrompt.String()).
		Str("old_completion", existing.PriceCompletion.String()).
		Str("new_completion", model.PriceCompletion.String()).
		Msg("Price changed")

	return &clients.PriceChange{
		ModelID:                 model.ModelID,
		Name:                    existing.Name,
		PrevPricePrompt:         existing.PricePrompt,
		PrevPriceCompletion:     existing.PriceCompletion,
		NewPricePrompt:          model.PricePrompt,
		NewPriceCompletion:      model.PriceCompletion,
		ChangePercentPrompt:     percentPrompt,
		ChangePercentCompletion: percentCompletion,
	}, nil
}

func calcPercentChange(old, new decimal.Decimal) *float64 {
	if old.IsZero() {
		return nil
	}
	change := new.Sub(old).Div(old).Mul(decimal.NewFromInt(100))
	f, _ := change.Float64()
	return &f
}
