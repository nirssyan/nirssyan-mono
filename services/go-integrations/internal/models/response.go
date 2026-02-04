package models

type WebhookResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

type ErrorResponse struct {
	Detail string `json:"detail"`
}

type HealthResponse struct {
	Status string `json:"status"`
}
