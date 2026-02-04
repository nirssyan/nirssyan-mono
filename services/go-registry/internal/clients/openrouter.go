package clients

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/rs/zerolog/log"
	"github.com/shopspring/decimal"
)

const (
	OpenRouterAPIURL = "https://openrouter.ai/api/v1/models"
)

// OpenRouterModel represents a model from OpenRouter API
type OpenRouterModel struct {
	ID           string          `json:"id"`
	Name         string          `json:"name"`
	Description  string          `json:"description,omitempty"`
	ContextLen   int             `json:"context_length"`
	Architecture *Architecture   `json:"architecture,omitempty"`
	Pricing      *Pricing        `json:"pricing,omitempty"`
	TopProvider  *TopProvider    `json:"top_provider,omitempty"`
	PerRequestLimits *PerRequestLimits `json:"per_request_limits,omitempty"`
	CreatedAt    int64           `json:"created,omitempty"`
}

type Architecture struct {
	Modality   string `json:"modality,omitempty"`
	Tokenizer  string `json:"tokenizer,omitempty"`
	InputCost  string `json:"instruct_type,omitempty"`
}

type Pricing struct {
	Prompt     string `json:"prompt"`
	Completion string `json:"completion"`
	Image      string `json:"image,omitempty"`
	Request    string `json:"request,omitempty"`
}

type TopProvider struct {
	ContextLength    int  `json:"context_length,omitempty"`
	MaxCompletionTokens int `json:"max_completion_tokens,omitempty"`
	IsModerated      bool `json:"is_moderated,omitempty"`
}

type PerRequestLimits struct {
	PromptTokens     int `json:"prompt_tokens,omitempty"`
	CompletionTokens int `json:"completion_tokens,omitempty"`
}

// ParsedModel is the internal representation of an LLM model
type ParsedModel struct {
	ModelID         string          `json:"model_id"`
	Name            string          `json:"name"`
	Description     string          `json:"description"`
	ContextLen      int             `json:"context_length"`
	PricePrompt     decimal.Decimal `json:"price_prompt"`
	PriceCompletion decimal.Decimal `json:"price_completion"`
	ModelCreatedAt  *int64          `json:"model_created_at"`
}

// OpenRouterClient fetches models from OpenRouter API
type OpenRouterClient struct {
	apiKey  string
	client  *http.Client
	baseURL string
}

func NewOpenRouterClient(apiKey string) *OpenRouterClient {
	return &OpenRouterClient{
		apiKey:  apiKey,
		client:  &http.Client{Timeout: 30 * time.Second},
		baseURL: OpenRouterAPIURL,
	}
}

// FetchModels retrieves all models from OpenRouter API
func (c *OpenRouterClient) FetchModels(ctx context.Context) ([]ParsedModel, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch models: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var response struct {
		Data []OpenRouterModel `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	models := make([]ParsedModel, 0, len(response.Data))
	for _, m := range response.Data {
		parsed := c.ParseModel(m)
		if parsed != nil {
			models = append(models, *parsed)
		}
	}

	log.Info().Int("count", len(models)).Msg("Fetched models from OpenRouter")
	return models, nil
}

// ParseModel converts API model to internal representation
func (c *OpenRouterClient) ParseModel(m OpenRouterModel) *ParsedModel {
	pricePrompt := decimal.Zero
	priceCompletion := decimal.Zero

	if m.Pricing != nil {
		if m.Pricing.Prompt != "" {
			pricePrompt, _ = decimal.NewFromString(m.Pricing.Prompt)
		}
		if m.Pricing.Completion != "" {
			priceCompletion, _ = decimal.NewFromString(m.Pricing.Completion)
		}
	}

	var createdAt *int64
	if m.CreatedAt > 0 {
		createdAt = &m.CreatedAt
	}

	return &ParsedModel{
		ModelID:         m.ID,
		Name:            m.Name,
		Description:     m.Description,
		ContextLen:      m.ContextLen,
		PricePrompt:     pricePrompt,
		PriceCompletion: priceCompletion,
		ModelCreatedAt:  createdAt,
	}
}
