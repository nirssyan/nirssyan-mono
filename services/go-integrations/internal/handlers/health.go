package handlers

import (
	"github.com/gofiber/fiber/v2"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/models"
)

func HealthCheck(c *fiber.Ctx) error {
	return c.JSON(models.HealthResponse{Status: "ok"})
}
