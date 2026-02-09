package middleware

import (
	"fmt"

	"github.com/getsentry/sentry-go"
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

				err := fmt.Errorf("panic: %v", r)
				sentry.WithScope(func(scope *sentry.Scope) {
					scope.SetTag("request_id", requestID)
					sentry.CaptureException(err)
				})

				_ = c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
					Detail: "Internal server error",
				})
			}
		}()
		return c.Next()
	}
}
