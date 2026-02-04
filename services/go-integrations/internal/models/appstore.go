package models

type AppStoreWebhookData struct {
	Type          string                 `json:"type"`
	ID            string                 `json:"id"`
	Version       int                    `json:"version"`
	Attributes    map[string]interface{} `json:"attributes"`
	Relationships map[string]interface{} `json:"relationships,omitempty"`
}

type AppStoreWebhookPayload struct {
	Data AppStoreWebhookData `json:"data"`
}

type AppStoreWebhookProcessingResult struct {
	Success      bool
	EventType    string
	TelegramSent bool
	ErrorMessage string
}
