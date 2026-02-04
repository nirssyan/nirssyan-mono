package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/services"
)

type SentryHandler struct {
	service *services.SentryService
}

func NewSentryHandler(service *services.SentryService) *SentryHandler {
	return &SentryHandler{service: service}
}

func (h *SentryHandler) HandleNotification(c *fiber.Ctx) error {
	var payload models.SentryWebhookPayload
	if err := c.BodyParser(&payload); err != nil {
		log.Error().Err(err).Msg("Failed to parse Sentry webhook payload")
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Detail: "Invalid JSON payload",
		})
	}

	result := h.service.ProcessWebhook(c.Context(), payload)

	if !result.Success {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Detail: result.ErrorMessage,
		})
	}

	return c.JSON(models.WebhookResponse{
		Success: true,
		Message: "Notification processed: " + result.Action,
	})
}
