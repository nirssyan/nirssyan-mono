package models

type GlitchTipField struct {
	Title string `json:"title"`
	Value string `json:"value"`
	Short bool   `json:"short"`
}

type GlitchTipAttachment struct {
	Title     string           `json:"title"`
	TitleLink string           `json:"title_link,omitempty"`
	Text      string           `json:"text,omitempty"`
	Color     string           `json:"color,omitempty"`
	Fields    []GlitchTipField `json:"fields"`
}

type GlitchTipWebhookPayload struct {
	Alias       string                `json:"alias,omitempty"`
	Text        string                `json:"text,omitempty"`
	Attachments []GlitchTipAttachment `json:"attachments"`
}

type GlitchTipWebhookProcessingResult struct {
	Success      bool
	ErrorTitle   string
	TelegramSent bool
	ErrorMessage string
}
