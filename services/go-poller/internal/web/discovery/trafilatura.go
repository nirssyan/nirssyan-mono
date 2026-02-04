package discovery

import (
	"bytes"
	"context"
	"net/url"
	"strings"

	"github.com/PuerkitoBio/goquery"
	trafilatura "github.com/markusmobius/go-trafilatura"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/rs/zerolog/log"
)

type TrafilaturaStep struct {
	httpClient *http.Client
}

func NewTrafilaturaStep(httpClient *http.Client) *TrafilaturaStep {
	return &TrafilaturaStep{
		httpClient: httpClient,
	}
}

func (s *TrafilaturaStep) Name() string {
	return "TRAFILATURA"
}

func (s *TrafilaturaStep) Priority() int {
	return 5
}

func (s *TrafilaturaStep) Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error) {
	resp, err := s.httpClient.Get(ctx, baseURL)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, nil
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(resp.Text()))
	if err != nil {
		return nil, err
	}

	parsedBaseURL, err := url.Parse(baseURL)
	if err != nil {
		return nil, err
	}

	baseDomain := parsedBaseURL.Host

	links := make([]string, 0)
	seen := make(map[string]bool)

	doc.Find("a[href]").Each(func(_ int, sel *goquery.Selection) {
		href, exists := sel.Attr("href")
		if !exists || href == "" {
			return
		}

		fullURL := resolveURL(baseURL, href)
		if fullURL == "" {
			return
		}

		linkParsed, err := url.Parse(fullURL)
		if err != nil {
			return
		}

		if linkParsed.Host != baseDomain {
			return
		}

		if isMediaURL(fullURL) {
			return
		}

		if seen[fullURL] {
			return
		}
		seen[fullURL] = true

		links = append(links, fullURL)
	})

	maxLinks := 10
	if len(links) > maxLinks {
		links = links[:maxLinks]
	}

	articles := make([]ArticleMetadata, 0)

	for _, link := range links {
		article, err := s.extractArticle(ctx, link)
		if err != nil {
			log.Debug().Err(err).Str("url", link).Msg("Trafilatura extraction failed")
			continue
		}

		if article != nil && article.Title != "" && article.Content != "" {
			articles = append(articles, *article)
		}
	}

	log.Debug().
		Str("url", baseURL).
		Int("links_found", len(links)).
		Int("articles_extracted", len(articles)).
		Msg("Trafilatura extraction complete")

	return articles, nil
}

func (s *TrafilaturaStep) extractArticle(ctx context.Context, articleURL string) (*ArticleMetadata, error) {
	resp, err := s.httpClient.Get(ctx, articleURL)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, nil
	}

	opts := trafilatura.Options{
		IncludeImages:  true,
		IncludeLinks:   true,
		ExcludeTables:  true,
		EnableFallback: true,
	}

	result, err := trafilatura.Extract(bytes.NewReader(resp.Body), opts)
	if err != nil {
		return nil, err
	}

	if result == nil || result.ContentText == "" {
		return nil, nil
	}

	var publishedDate string
	if !result.Metadata.Date.IsZero() {
		publishedDate = result.Metadata.Date.Format("2006-01-02")
	}

	article := &ArticleMetadata{
		URL:           articleURL,
		Title:         result.Metadata.Title,
		Content:       result.ContentText,
		PublishedDate: publishedDate,
		Source:        "TRAFILATURA",
	}

	if result.Metadata.Image != "" {
		article.MediaURLs = []string{result.Metadata.Image}
	}

	return article, nil
}
