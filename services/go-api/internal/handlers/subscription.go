package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/clients"
	"github.com/MargoRSq/infatium-mono/services/go-api/internal/middleware"
	"github.com/MargoRSq/infatium-mono/services/go-api/repository"
	"github.com/rs/zerolog/log"
)

type SubscriptionHandler struct {
	subscriptionRepo *repository.SubscriptionRepository
	usersFeedRepo    *repository.UsersFeedRepository
	ruStoreClient    *clients.RuStoreClient
}

func NewSubscriptionHandler(
	subscriptionRepo *repository.SubscriptionRepository,
	usersFeedRepo *repository.UsersFeedRepository,
	ruStoreClient *clients.RuStoreClient,
) *SubscriptionHandler {
	return &SubscriptionHandler{
		subscriptionRepo: subscriptionRepo,
		usersFeedRepo:    usersFeedRepo,
		ruStoreClient:    ruStoreClient,
	}
}

func (h *SubscriptionHandler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/current", h.GetCurrentSubscription)
	r.Get("/limits", h.GetLimits)
	r.Post("/validate", h.ValidateSubscription)
	r.Post("/manual", h.CreateManualSubscription)

	return r
}

type CurrentSubscriptionResponse struct {
	HasActiveSubscription bool         `json:"has_active_subscription"`
	Plan                  PlanResponse `json:"plan"`
	ActiveFeedsCount      int          `json:"active_feeds_count"`
	SubscriptionID        *uuid.UUID   `json:"subscription_id,omitempty"`
	Platform              *string      `json:"platform,omitempty"`
	StartDate             *string      `json:"start_date,omitempty"`
	ExpiryDate            *string      `json:"expiry_date,omitempty"`
	IsAutoRenewing        bool         `json:"is_auto_renewing"`
	Status                *string      `json:"status,omitempty"`
}

type PlanResponse struct {
	ID                  uuid.UUID `json:"id"`
	PlanType            string    `json:"plan_type"`
	FeedsLimit          int       `json:"feeds_limit"`
	SourcesPerFeedLimit int       `json:"sources_per_feed_limit"`
	PriceAmountMicros   *int64    `json:"price_amount_micros,omitempty"`
	IsActive            bool      `json:"is_active"`
	CreatedAt           string    `json:"created_at"`
}

func (h *SubscriptionHandler) GetCurrentSubscription(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	activeFeedsCount, err := h.usersFeedRepo.CountUserFeeds(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to count user feeds")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	sub, err := h.subscriptionRepo.GetCurrentSubscription(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get current subscription")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if sub == nil {
		freePlan, err := h.subscriptionRepo.GetFreePlan(r.Context())
		if err != nil || freePlan == nil {
			writeJSON(w, http.StatusOK, CurrentSubscriptionResponse{
				HasActiveSubscription: false,
				Plan: PlanResponse{
					ID:                  uuid.Nil,
					PlanType:            "FREE",
					FeedsLimit:          3,
					SourcesPerFeedLimit: 5,
					IsActive:            true,
					CreatedAt:           time.Now().Format(time.RFC3339),
				},
				ActiveFeedsCount: activeFeedsCount,
				IsAutoRenewing:   false,
			})
			return
		}

		var priceAmountMicros *int64
		if freePlan.PriceAmountMicros > 0 {
			priceAmountMicros = &freePlan.PriceAmountMicros
		}

		writeJSON(w, http.StatusOK, CurrentSubscriptionResponse{
			HasActiveSubscription: false,
			Plan: PlanResponse{
				ID:                  freePlan.ID,
				PlanType:            freePlan.PlanType,
				FeedsLimit:          freePlan.FeedsLimit,
				SourcesPerFeedLimit: freePlan.SourcesPerFeedLimit,
				PriceAmountMicros:   priceAmountMicros,
				IsActive:            freePlan.IsActive,
				CreatedAt:           time.Now().Format(time.RFC3339),
			},
			ActiveFeedsCount: activeFeedsCount,
			IsAutoRenewing:   false,
		})
		return
	}

	plan, err := h.subscriptionRepo.GetPlanByID(r.Context(), sub.SubscriptionPlanID)
	if err != nil || plan == nil {
		log.Error().Err(err).Msg("Failed to get subscription plan")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	var expiryDate *string
	if sub.ExpiryDate != nil {
		exp := sub.ExpiryDate.Format(time.RFC3339)
		expiryDate = &exp
	}

	startDate := sub.StartDate.Format(time.RFC3339)

	var priceAmountMicros *int64
	if plan.PriceAmountMicros > 0 {
		priceAmountMicros = &plan.PriceAmountMicros
	}

	writeJSON(w, http.StatusOK, CurrentSubscriptionResponse{
		HasActiveSubscription: true,
		Plan: PlanResponse{
			ID:                  plan.ID,
			PlanType:            plan.PlanType,
			FeedsLimit:          plan.FeedsLimit,
			SourcesPerFeedLimit: plan.SourcesPerFeedLimit,
			PriceAmountMicros:   priceAmountMicros,
			IsActive:            plan.IsActive,
			CreatedAt:           sub.CreatedAt.Format(time.RFC3339),
		},
		ActiveFeedsCount: activeFeedsCount,
		SubscriptionID:   &sub.ID,
		Platform:         &sub.Platform,
		StartDate:        &startDate,
		ExpiryDate:       expiryDate,
		IsAutoRenewing:   sub.IsAutoRenewing,
		Status:           &sub.Status,
	})
}

type LimitsResponse struct {
	PlanType              string  `json:"plan_type"`
	FeedsLimit            int     `json:"feeds_limit"`
	SourcesPerFeedLimit   int     `json:"sources_per_feed_limit"`
	HasActiveSubscription bool    `json:"has_active_subscription"`
	ExpiryDate            *string `json:"expiry_date,omitempty"`
}

func (h *SubscriptionHandler) GetLimits(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	sub, err := h.subscriptionRepo.GetCurrentSubscription(r.Context(), userID)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get subscription")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	if sub != nil {
		plan, err := h.subscriptionRepo.GetPlanByID(r.Context(), sub.SubscriptionPlanID)
		if err != nil || plan == nil {
			log.Error().Err(err).Msg("Failed to get plan")
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		var expiryDate *string
		if sub.ExpiryDate != nil {
			exp := sub.ExpiryDate.Format(time.RFC3339)
			expiryDate = &exp
		}

		writeJSON(w, http.StatusOK, LimitsResponse{
			PlanType:              plan.PlanType,
			FeedsLimit:            plan.FeedsLimit,
			SourcesPerFeedLimit:   plan.SourcesPerFeedLimit,
			HasActiveSubscription: true,
			ExpiryDate:            expiryDate,
		})
		return
	}

	freePlan, _ := h.subscriptionRepo.GetFreePlan(r.Context())
	if freePlan != nil {
		writeJSON(w, http.StatusOK, LimitsResponse{
			PlanType:              freePlan.PlanType,
			FeedsLimit:            freePlan.FeedsLimit,
			SourcesPerFeedLimit:   freePlan.SourcesPerFeedLimit,
			HasActiveSubscription: false,
			ExpiryDate:            nil,
		})
		return
	}

	writeJSON(w, http.StatusOK, LimitsResponse{
		PlanType:              "FREE",
		FeedsLimit:            3,
		SourcesPerFeedLimit:   5,
		HasActiveSubscription: false,
		ExpiryDate:            nil,
	})
}

type CreateManualSubscriptionRequest struct {
	UserID   uuid.UUID `json:"user_id"`
	Months   int       `json:"months"`
	PlanType string    `json:"plan_type"`
}

type ManualSubscriptionResponse struct {
	Success        bool      `json:"success"`
	SubscriptionID uuid.UUID `json:"subscription_id"`
	PlanType       string    `json:"plan_type"`
	Status         string    `json:"status"`
	ExpiryDate     string    `json:"expiry_date"`
	Message        string    `json:"message"`
}

func (h *SubscriptionHandler) CreateManualSubscription(w http.ResponseWriter, r *http.Request) {
	var req CreateManualSubscriptionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.UserID == uuid.Nil {
		http.Error(w, "user_id is required", http.StatusBadRequest)
		return
	}

	if req.Months <= 0 {
		req.Months = 1
	}

	if req.PlanType == "" {
		req.PlanType = "PRO"
	}

	plan, err := h.subscriptionRepo.GetPlanByType(r.Context(), req.PlanType)
	if err != nil || plan == nil {
		http.Error(w, "plan not found", http.StatusNotFound)
		return
	}

	if err := h.subscriptionRepo.DeactivateUserSubscriptions(r.Context(), req.UserID); err != nil {
		log.Error().Err(err).Msg("Failed to deactivate existing subscriptions")
	}

	expiresAt := time.Now().AddDate(0, req.Months, 0)

	sub, err := h.subscriptionRepo.Create(r.Context(), repository.CreateSubscriptionParams{
		UserID:    req.UserID,
		PlanID:    plan.ID,
		Status:    "ACTIVE",
		Platform:  "MANUAL",
		ExpiresAt: &expiresAt,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create subscription")
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, ManualSubscriptionResponse{
		Success:        true,
		SubscriptionID: sub.ID,
		PlanType:       plan.PlanType,
		Status:         sub.Status,
		ExpiryDate:     expiresAt.Format(time.RFC3339),
		Message:        fmt.Sprintf("Subscription created for %d months", req.Months),
	})
}

type ValidateSubscriptionRequest struct {
	PackageName    string `json:"package_name"`
	SubscriptionID string `json:"subscription_id"`
	PurchaseToken  string `json:"purchase_token"`
}

type ValidateSubscriptionResponse struct {
	Success        bool       `json:"success"`
	SubscriptionID *uuid.UUID `json:"subscription_id,omitempty"`
	PlanType       *string    `json:"plan_type,omitempty"`
	Status         *string    `json:"status,omitempty"`
	ExpiryDate     *string    `json:"expiry_date,omitempty"`
	Message        string     `json:"message"`
}

func (h *SubscriptionHandler) ValidateSubscription(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req ValidateSubscriptionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.PackageName == "" || req.SubscriptionID == "" || req.PurchaseToken == "" {
		writeJSON(w, http.StatusBadRequest, ValidateSubscriptionResponse{
			Success: false,
			Message: "package_name, subscription_id, and purchase_token are required",
		})
		return
	}

	log.Info().
		Str("user_id", userID.String()).
		Str("subscription_id", req.SubscriptionID).
		Msg("Validating subscription")

	if h.ruStoreClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ValidateSubscriptionResponse{
			Success: false,
			Message: "RuStore integration not configured",
		})
		return
	}

	ruStoreResp, err := h.ruStoreClient.ValidateSubscription(r.Context(), req.PackageName, req.SubscriptionID, req.PurchaseToken)
	if err != nil {
		log.Error().Err(err).Msg("RuStore validation failed")
		writeJSON(w, http.StatusBadRequest, ValidateSubscriptionResponse{
			Success: false,
			Message: fmt.Sprintf("Subscription validation failed: %s", err.Error()),
		})
		return
	}

	if ruStoreResp.PaymentState != 1 {
		log.Warn().
			Int("payment_state", ruStoreResp.PaymentState).
			Msg("Subscription payment state is not active")
		writeJSON(w, http.StatusBadRequest, ValidateSubscriptionResponse{
			Success: false,
			Message: "Subscription payment is not active",
		})
		return
	}

	existingSub, _ := h.subscriptionRepo.GetByPlatformSubscriptionID(r.Context(), req.PurchaseToken)
	if existingSub != nil {
		expiryDateStr := existingSub.ExpiryDate.Format(time.RFC3339)
		status := existingSub.Status
		plan, _ := h.subscriptionRepo.GetPlanByID(r.Context(), existingSub.SubscriptionPlanID)
		planType := "PRO"
		if plan != nil {
			planType = plan.PlanType
		}
		writeJSON(w, http.StatusOK, ValidateSubscriptionResponse{
			Success:        true,
			SubscriptionID: &existingSub.ID,
			PlanType:       &planType,
			Status:         &status,
			ExpiryDate:     &expiryDateStr,
			Message:        "Subscription already exists",
		})
		return
	}

	proPlan, err := h.subscriptionRepo.GetPlanByType(r.Context(), "PRO")
	if err != nil || proPlan == nil {
		log.Error().Err(err).Msg("Failed to get PRO plan")
		writeJSON(w, http.StatusInternalServerError, ValidateSubscriptionResponse{
			Success: false,
			Message: "Failed to get subscription plan",
		})
		return
	}

	if err := h.subscriptionRepo.DeactivateUserSubscriptions(r.Context(), userID); err != nil {
		log.Error().Err(err).Msg("Failed to deactivate existing subscriptions")
	}

	expiryTime := time.Unix(0, ruStoreResp.ExpiryTimeMillis*int64(time.Millisecond))
	externalID := req.PurchaseToken

	sub, err := h.subscriptionRepo.Create(r.Context(), repository.CreateSubscriptionParams{
		UserID:     userID,
		PlanID:     proPlan.ID,
		Status:     "ACTIVE",
		Platform:   "RUSTORE",
		ExternalID: &externalID,
		ExpiresAt:  &expiryTime,
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to create subscription")
		writeJSON(w, http.StatusInternalServerError, ValidateSubscriptionResponse{
			Success: false,
			Message: "Failed to create subscription",
		})
		return
	}

	expiryDateStr := expiryTime.Format(time.RFC3339)
	status := "ACTIVE"
	planType := proPlan.PlanType

	writeJSON(w, http.StatusOK, ValidateSubscriptionResponse{
		Success:        true,
		SubscriptionID: &sub.ID,
		PlanType:       &planType,
		Status:         &status,
		ExpiryDate:     &expiryDateStr,
		Message:        "Subscription validated successfully",
	})
}
