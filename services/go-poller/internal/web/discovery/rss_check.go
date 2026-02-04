package discovery

import (
	"context"
	"strings"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/mmcdole/gofeed"
	"github.com/rs/zerolog/log"
)

type RSSCheckStep struct {
	httpClient  *http.Client
	feedParser  *gofeed.Parser
	lastFeedURL string
}

func NewRSSCheckStep(httpClient *http.Client) *RSSCheckStep {
	return &RSSCheckStep{
		httpClient: httpClient,
		feedParser: gofeed.NewParser(),
	}
}

func (s *RSSCheckStep) Name() string {
	return "RSS_FEEDPARSER"
}

func (s *RSSCheckStep) Priority() int {
	return 1
}

func (s *RSSCheckStep) Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error) {
	normalizedURL := strings.TrimSuffix(baseURL, "/")

	if s.isRSSURL(normalizedURL) {
		return s.parseFeed(ctx, normalizedURL)
	}

	resp, err := s.httpClient.Get(ctx, normalizedURL)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, nil
	}

	content := strings.ToLower(resp.Text()[:min(500, len(resp.Text()))])

	rssIndicators := []string{
		"<rss",
		"<feed",
		"<channel>",
		`xmlns="http://www.w3.org/2005/atom`,
	}

	for _, indicator := range rssIndicators {
		if strings.Contains(content, indicator) {
			return s.parseFeed(ctx, normalizedURL)
		}
	}

	return nil, nil
}

func (s *RSSCheckStep) isRSSURL(url string) bool {
	rssSuffixes := []string{
		".xml",
		".rss",
		"/rss",
		"/feed",
		"/atom",
		"/rss.xml",
		"/feed.xml",
		"/atom.xml",
	}

	for _, suffix := range rssSuffixes {
		if strings.HasSuffix(url, suffix) {
			return true
		}
	}

	return false
}

func (s *RSSCheckStep) parseFeed(ctx context.Context, feedURL string) ([]ArticleMetadata, error) {
	resp, err := s.httpClient.Get(ctx, feedURL)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, nil
	}

	feed, err := s.feedParser.ParseString(resp.Text())
	if err != nil {
		return nil, err
	}

	s.lastFeedURL = feedURL

	articles := make([]ArticleMetadata, 0, len(feed.Items))

	for _, item := range feed.Items {
		var content string
		if item.Content != "" {
			content = item.Content
		}

		var pubDate string
		if item.PublishedParsed != nil {
			pubDate = item.PublishedParsed.Format("2006-01-02T15:04:05Z07:00")
		}

		mediaURLs := extractMediaFromFeedItem(item, feedURL)

		articles = append(articles, ArticleMetadata{
			URL:           item.Link,
			Title:         item.Title,
			PublishedDate: pubDate,
			Source:        "RSS_FEEDPARSER",
			Content:       content,
			Summary:       item.Description,
			MediaURLs:     mediaURLs,
		})
	}

	log.Debug().
		Str("url", feedURL).
		Int("items", len(articles)).
		Msg("Parsed RSS feed")

	return articles, nil
}

func extractMediaFromFeedItem(item *gofeed.Item, baseURL string) []string {
	var mediaURLs []string
	seen := make(map[string]bool)

	for _, enc := range item.Enclosures {
		if enc.URL != "" && !seen[enc.URL] {
			seen[enc.URL] = true
			mediaURLs = append(mediaURLs, enc.URL)
		}
	}

	if item.Image != nil && item.Image.URL != "" && !seen[item.Image.URL] {
		seen[item.Image.URL] = true
		mediaURLs = append(mediaURLs, item.Image.URL)
	}

	for _, ext := range item.Extensions {
		for _, items := range ext {
			for _, extItem := range items {
				if extItem.Name == "content" || extItem.Name == "thumbnail" {
					if url, ok := extItem.Attrs["url"]; ok && url != "" && !seen[url] {
						seen[url] = true
						mediaURLs = append(mediaURLs, url)
					}
				}
			}
		}
	}

	return mediaURLs
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
