package crawl4ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/rs/zerolog/log"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

type ExtractionConfig struct {
	Type   string `json:"type"`
	Params any    `json:"params,omitempty"`
}

type CrawlRequest struct {
	URLs             []string          `json:"urls"`
	SessionID        string            `json:"session_id,omitempty"`
	JSCode           []string          `json:"js_code,omitempty"`
	WaitFor          string            `json:"wait_for,omitempty"`
	CSSSelector      string            `json:"css_selector,omitempty"`
	ExtractionConfig *ExtractionConfig `json:"extraction_strategy,omitempty"`
	CacheMode        string            `json:"cache_mode,omitempty"`
	MagicMode        bool              `json:"magic,omitempty"`
}

type CrawlResult struct {
	URL             string `json:"url"`
	HTML            string `json:"html"`
	CleanedHTML     string `json:"cleaned_html"`
	Markdown        string `json:"markdown"`
	ExtractedContent string `json:"extracted_content"`
	Success         bool   `json:"success"`
	ErrorMessage    string `json:"error_message"`
}

type CrawlResponse struct {
	Results []CrawlResult `json:"results"`
	Success bool          `json:"success"`
}

type JSRequest struct {
	SessionID string `json:"session_id"`
	JSCode    string `json:"js_code"`
}

type JSResponse struct {
	Result  string `json:"result"`
	Success bool   `json:"success"`
}

func (c *Client) Crawl(ctx context.Context, req CrawlRequest) (*CrawlResponse, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal crawl request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/crawl", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	log.Debug().
		Str("session_id", req.SessionID).
		Strs("urls", req.URLs).
		Msg("Sending crawl request")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("execute crawl request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("crawl4ai returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var crawlResp CrawlResponse
	if err := json.Unmarshal(respBody, &crawlResp); err != nil {
		return nil, fmt.Errorf("unmarshal crawl response: %w", err)
	}

	return &crawlResp, nil
}

func (c *Client) ExecuteJS(ctx context.Context, sessionID, jsCode string) (*JSResponse, error) {
	body, err := json.Marshal(JSRequest{
		SessionID: sessionID,
		JSCode:    jsCode,
	})
	if err != nil {
		return nil, fmt.Errorf("marshal js request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/execute_js", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("execute js request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("crawl4ai returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var jsResp JSResponse
	if err := json.Unmarshal(respBody, &jsResp); err != nil {
		return nil, fmt.Errorf("unmarshal js response: %w", err)
	}

	return &jsResp, nil
}

func (c *Client) CloseSession(ctx context.Context, sessionID string) error {
	body, err := json.Marshal(map[string]string{"session_id": sessionID})
	if err != nil {
		return fmt.Errorf("marshal close request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodDelete, c.baseURL+"/session", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return fmt.Errorf("close session request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("crawl4ai returned status %d: %s", resp.StatusCode, string(respBody))
	}

	log.Debug().Str("session_id", sessionID).Msg("Session closed")
	return nil
}
