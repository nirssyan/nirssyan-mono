package discovery

import (
	"context"
	"net/url"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/rs/zerolog/log"
)

type HTMLParserStep struct {
	httpClient *http.Client
}

func NewHTMLParserStep(httpClient *http.Client) *HTMLParserStep {
	return &HTMLParserStep{
		httpClient: httpClient,
	}
}

func (s *HTMLParserStep) Name() string {
	return "HTML"
}

func (s *HTMLParserStep) Priority() int {
	return 4
}

func (s *HTMLParserStep) Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error) {
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

	articles := make([]ArticleMetadata, 0)
	seen := make(map[string]bool)

	selectors := []string{
		"article a[href]",
		".post a[href]",
		".entry a[href]",
		"a[href*='/blog/']",
		"a[href*='/post/']",
		"a[href*='/article/']",
		"a[href*='/2024/']",
		"a[href*='/2025/']",
		"a[href*='/2026/']",
	}

	for _, selector := range selectors {
		doc.Find(selector).Each(func(_ int, sel *goquery.Selection) {
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

			title := sel.Text()
			title = strings.TrimSpace(title)

			if titleAttr, exists := sel.Attr("title"); exists && titleAttr != "" {
				title = titleAttr
			}

			articles = append(articles, ArticleMetadata{
				URL:    fullURL,
				Title:  title,
				Source: "HTML",
			})
		})
	}

	maxArticles := 50
	if len(articles) > maxArticles {
		articles = articles[:maxArticles]
	}

	log.Debug().
		Str("url", baseURL).
		Int("articles", len(articles)).
		Msg("Found articles via HTML parsing")

	return articles, nil
}

func resolveURL(baseURL, href string) string {
	if href == "" {
		return ""
	}

	if strings.HasPrefix(href, "http://") || strings.HasPrefix(href, "https://") {
		return href
	}

	base, err := url.Parse(baseURL)
	if err != nil {
		return ""
	}

	ref, err := url.Parse(href)
	if err != nil {
		return ""
	}

	resolved := base.ResolveReference(ref)
	return resolved.String()
}

func isMediaURL(urlStr string) bool {
	mediaExtensions := []string{
		".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".bmp", ".ico",
		".mp4", ".webm", ".ogg", ".mov", ".avi", ".mkv", ".m4v", ".flv",
		".wmv", ".3gp", ".m3u8", ".pdf", ".doc", ".docx", ".xls", ".xlsx",
	}

	lower := strings.ToLower(urlStr)

	for _, ext := range mediaExtensions {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}

	return false
}
