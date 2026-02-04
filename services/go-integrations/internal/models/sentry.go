package models

type SentryProject struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Slug     string `json:"slug"`
	Platform string `json:"platform,omitempty"`
}

type SentryIssueMetadata struct {
	Type  string `json:"type,omitempty"`
	Value string `json:"value,omitempty"`
	Title string `json:"title,omitempty"`
}

type SentryIssue struct {
	ID            string               `json:"id"`
	ShortID       string               `json:"shortId"`
	Title         string               `json:"title"`
	Culprit       string               `json:"culprit,omitempty"`
	Level         string               `json:"level"`
	Status        string               `json:"status"`
	Substatus     string               `json:"substatus,omitempty"`
	Platform      string               `json:"platform,omitempty"`
	Project       SentryProject        `json:"project"`
	Metadata      *SentryIssueMetadata `json:"metadata,omitempty"`
	Count         string               `json:"count,omitempty"`
	UserCount     int                  `json:"userCount,omitempty"`
	FirstSeen     string               `json:"firstSeen,omitempty"`
	LastSeen      string               `json:"lastSeen,omitempty"`
	Permalink     string               `json:"permalink,omitempty"`
	WebURL        string               `json:"web_url,omitempty"`
	Priority      string               `json:"priority,omitempty"`
	IssueType     string               `json:"issueType,omitempty"`
	IssueCategory string               `json:"issueCategory,omitempty"`
}

type SentryActor struct {
	Type string `json:"type"`
	ID   string `json:"id,omitempty"`
	Name string `json:"name,omitempty"`
}

type SentryInstallation struct {
	UUID string `json:"uuid"`
}

type SentryWebhookData struct {
	Issue SentryIssue `json:"issue"`
}

type SentryWebhookPayload struct {
	Action       string              `json:"action"`
	Data         SentryWebhookData   `json:"data"`
	Installation *SentryInstallation `json:"installation,omitempty"`
	Actor        *SentryActor        `json:"actor,omitempty"`
}

type SentryWebhookProcessingResult struct {
	Success      bool
	Action       string
	IssueID      string
	TelegramSent bool
	ErrorMessage string
}
