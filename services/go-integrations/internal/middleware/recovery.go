package middleware

import (
	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog/log"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
)

func Recovery() fiber.Handler {
	return func(c *fiber.Ctx) error {
		defer func() {
			if r := recover(); r != nil {
				requestID := GetRequestID(c)
				log.Error().
					Str("request_id", requestID).
					Interface("panic", r).
					Msg("recovered from panic")

				_ = c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
					Detail: "Internal server error",
				})
			}
		}()
		return c.Next()
	}
}
