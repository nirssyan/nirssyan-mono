package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/services"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/pkg/hmac"
)

type AppStoreHandler struct {
	service *services.AppStoreService
}

func NewAppStoreHandler(service *services.AppStoreService) *AppStoreHandler {
	return &AppStoreHandler{service: service}
}

func (h *AppStoreHandler) HandleNotification(c *fiber.Ctx) error {
	signature := c.Get("X-Apple-SIGNATURE")
	if signature == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Detail: "Missing X-Apple-SIGNATURE header",
		})
	}

	rawBody := c.Body()

	if err := h.service.VerifySignature(rawBody, signature); err != nil {
		log.Warn().Err(err).Msg("App Store signature verification failed")

		if err == hmac.ErrSecretNotConfigured {
			return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
				Detail: "Webhook processing not configured",
			})
		}

		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Detail: "Invalid signature",
		})
	}

	var payload models.AppStoreWebhookPayload
	if err := c.BodyParser(&payload); err != nil {
		log.Error().Err(err).Msg("Failed to parse App Store webhook payload")
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Detail: "Invalid JSON payload",
		})
	}

	result := h.service.ProcessWebhook(c.Context(), payload)

	return c.JSON(models.WebhookResponse{
		Success: result.Success,
		Message: "Notification processed: " + result.EventType,
	})
}
