package rss

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	trafilatura "github.com/markusmobius/go-trafilatura"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/rs/zerolog/log"
)

type ContentEnricher struct {
	httpClient       *http.Client
	minContentLength int
}

func NewContentEnricher(httpClient *http.Client, minContentLength int) *ContentEnricher {
	return &ContentEnricher{
		httpClient:       httpClient,
		minContentLength: minContentLength,
	}
}

type ExtractedContent struct {
	Text      string
	Title     string
	Author    string
	Date      string
	Image     string
	Sitename  string
}

func (e *ContentEnricher) EnrichItem(ctx context.Context, item *RSSItem) error {
	currentContent := item.Content
	if currentContent == "" {
		currentContent = item.Description
	}

	if len(currentContent) >= e.minContentLength {
		return nil
	}

	if item.Link == "" {
		return nil
	}

	content, imageURL, err := e.FetchArticleContent(ctx, item.Link)
	if err != nil {
		log.Debug().
			Err(err).
			Str("url", item.Link).
			Msg("Failed to fetch article content")
		return nil
	}

	if content != "" && len(content) >= e.minContentLength {
		item.Content = content
		log.Debug().
			Str("url", item.Link).
			Int("content_length", len(content)).
			Msg("Enriched item with trafilatura content")
	}

	if imageURL != "" && item.EnclosureURL == "" {
		item.EnclosureURL = imageURL
	}

	return nil
}

func (e *ContentEnricher) FetchArticleContent(ctx context.Context, articleURL string) (string, string, error) {
	resp, err := e.httpClient.Get(ctx, articleURL)
	if err != nil {
		return "", "", fmt.Errorf("fetch article: %w", err)
	}

	if resp.StatusCode != 200 {
		return "", "", fmt.Errorf("article returned status %d", resp.StatusCode)
	}

	opts := trafilatura.Options{
		IncludeImages:  true,
		IncludeLinks:   true,
		ExcludeTables:  true,
		EnableFallback: true,
	}

	result, err := trafilatura.Extract(bytes.NewReader(resp.Body), opts)
	if err != nil {
		return "", "", fmt.Errorf("trafilatura extract: %w", err)
	}

	if result == nil || result.ContentText == "" {
		return "", "", nil
	}

	imageURL := result.Metadata.Image

	return result.ContentText, imageURL, nil
}

func (e *ContentEnricher) ExtractWithMetadata(ctx context.Context, articleURL string) (*ExtractedContent, error) {
	resp, err := e.httpClient.Get(ctx, articleURL)
	if err != nil {
		return nil, fmt.Errorf("fetch article: %w", err)
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("article returned status %d", resp.StatusCode)
	}

	opts := trafilatura.Options{
		IncludeImages:  true,
		IncludeLinks:   true,
		ExcludeTables:  true,
		EnableFallback: true,
	}

	result, err := trafilatura.Extract(bytes.NewReader(resp.Body), opts)
	if err != nil {
		return nil, fmt.Errorf("trafilatura extract: %w", err)
	}

	if result == nil {
		return nil, nil
	}

	var dateStr string
	if !result.Metadata.Date.IsZero() {
		dateStr = result.Metadata.Date.Format("2006-01-02")
	}

	extracted := &ExtractedContent{
		Text:     result.ContentText,
		Title:    result.Metadata.Title,
		Author:   result.Metadata.Author,
		Date:     dateStr,
		Image:    result.Metadata.Image,
		Sitename: result.Metadata.Sitename,
	}

	return extracted, nil
}

func parseTrafilaturaJSON(data []byte) (*ExtractedContent, error) {
	var result struct {
		Text     string `json:"text"`
		Title    string `json:"title"`
		Author   string `json:"author"`
		Date     string `json:"date"`
		Image    string `json:"image"`
		Sitename string `json:"sitename"`
	}

	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return &ExtractedContent{
		Text:     result.Text,
		Title:    result.Title,
		Author:   result.Author,
		Date:     result.Date,
		Image:    result.Image,
		Sitename: result.Sitename,
	}, nil
}
