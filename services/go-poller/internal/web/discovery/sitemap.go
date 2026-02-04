package discovery

import (
	"context"
	"fmt"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/rs/zerolog/log"
)

type SitemapStep struct {
	httpClient *http.Client
}

func NewSitemapStep(httpClient *http.Client) *SitemapStep {
	return &SitemapStep{
		httpClient: httpClient,
	}
}

func (s *SitemapStep) Name() string {
	return "SITEMAP"
}

func (s *SitemapStep) Priority() int {
	return 3
}

func (s *SitemapStep) Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error) {
	baseURL = strings.TrimSuffix(baseURL, "/")

	sitemapVariants := []string{
		fmt.Sprintf("%s/sitemap.xml", baseURL),
		fmt.Sprintf("%s/sitemap_index.xml", baseURL),
		fmt.Sprintf("%s/sitemap-index.xml", baseURL),
	}

	for _, sitemapURL := range sitemapVariants {
		articles, err := s.parseSitemap(ctx, sitemapURL, baseURL)
		if err != nil {
			log.Debug().Err(err).Str("url", sitemapURL).Msg("Sitemap parsing failed")
			continue
		}

		if len(articles) > 0 {
			log.Info().
				Str("sitemap", sitemapURL).
				Int("articles", len(articles)).
				Msg("Found articles in sitemap")
			return articles, nil
		}
	}

	return nil, nil
}

func (s *SitemapStep) parseSitemap(ctx context.Context, sitemapURL, baseURL string) ([]ArticleMetadata, error) {
	resp, err := s.httpClient.Get(ctx, sitemapURL)
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

	var urls []string
	doc.Find("loc").Each(func(_ int, sel *goquery.Selection) {
		url := strings.TrimSpace(sel.Text())
		if url != "" {
			urls = append(urls, url)
		}
	})

	if len(urls) == 0 {
		return nil, nil
	}

	yearPattern := regexp.MustCompile(`/20[2-9][0-9]/`)

	articleURLs := make([]string, 0)
	for _, url := range urls {
		if yearPattern.MatchString(url) {
			articleURLs = append(articleURLs, url)
		}
	}

	if len(articleURLs) == 0 {
		articleURLs = filterArticleURLs(urls, baseURL)
	}

	maxArticles := 50
	if len(articleURLs) > maxArticles {
		articleURLs = articleURLs[:maxArticles]
	}

	articles := make([]ArticleMetadata, 0, len(articleURLs))
	for _, url := range articleURLs {
		articles = append(articles, ArticleMetadata{
			URL:    url,
			Source: "SITEMAP",
		})
	}

	return articles, nil
}

func filterArticleURLs(urls []string, baseURL string) []string {
	articlePatterns := []string{
		"/article/",
		"/post/",
		"/blog/",
		"/news/",
		"/story/",
		"/entry/",
	}

	result := make([]string, 0)

	for _, url := range urls {
		for _, pattern := range articlePatterns {
			if strings.Contains(url, pattern) {
				result = append(result, url)
				break
			}
		}
	}

	return result
}
