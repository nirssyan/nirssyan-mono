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

type CrawlerConfig struct {
	SessionID string   `json:"session_id,omitempty"`
	JSCode    []string `json:"js_code,omitempty"`
	WaitFor   string   `json:"wait_for,omitempty"`
	CacheMode string   `json:"cache_mode,omitempty"`
}

type CrawlRequest struct {
	URLs          []string       `json:"urls"`
	CrawlerConfig *CrawlerConfig `json:"crawler_config,omitempty"`
}

type MarkdownResult struct {
	RawMarkdown string `json:"raw_markdown"`
}

type JSExecutionResult struct {
	Success bool     `json:"success"`
	Results []string `json:"results"`
}

type CrawlResult struct {
	URL               string             `json:"url"`
	HTML              string             `json:"html"`
	CleanedHTML       string             `json:"cleaned_html"`
	Markdown          json.RawMessage    `json:"markdown"`
	Success           bool               `json:"success"`
	ErrorMessage      string             `json:"error_message"`
	SessionID         string             `json:"session_id"`
	JSExecutionResult *JSExecutionResult `json:"js_execution_result"`
}

func (r *CrawlResult) GetMarkdown() string {
	var md MarkdownResult
	if err := json.Unmarshal(r.Markdown, &md); err != nil {
		return string(r.Markdown)
	}
	return md.RawMarkdown
}

type CrawlResponse struct {
	Results []CrawlResult `json:"results"`
	Success bool          `json:"success"`
}

func (c *Client) Crawl(ctx context.Context, req CrawlRequest) (*CrawlResponse, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal crawl request: %w", err)
	}

	sessionID := ""
	if req.CrawlerConfig != nil {
		sessionID = req.CrawlerConfig.SessionID
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/crawl", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	log.Debug().
		Str("session_id", sessionID).
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

func (c *Client) ExecuteJS(ctx context.Context, url string, scripts []string) ([]string, error) {
	reqBody := map[string]any{
		"url":     url,
		"scripts": scripts,
	}
	body, err := json.Marshal(reqBody)
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

	var jsResp struct {
		Success bool     `json:"success"`
		Results []string `json:"results"`
	}
	if err := json.Unmarshal(respBody, &jsResp); err != nil {
		return nil, fmt.Errorf("unmarshal js response: %w", err)
	}

	return jsResp.Results, nil
}
