package discovery

import (
	"context"
	"fmt"
	"strings"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/mmcdole/gofeed"
	"github.com/rs/zerolog/log"
)

type RSSEndpointsStep struct {
	httpClient  *http.Client
	feedParser  *gofeed.Parser
	lastFeedURL string
}

func NewRSSEndpointsStep(httpClient *http.Client) *RSSEndpointsStep {
	return &RSSEndpointsStep{
		httpClient: httpClient,
		feedParser: gofeed.NewParser(),
	}
}

func (s *RSSEndpointsStep) Name() string {
	return "RSS_ENDPOINTS"
}

func (s *RSSEndpointsStep) Priority() int {
	return 2
}

func (s *RSSEndpointsStep) Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error) {
	baseURL = strings.TrimSuffix(baseURL, "/")

	endpoints := []string{
		"/feed",
		"/rss",
		"/rss.xml",
		"/atom.xml",
		"/feed.xml",
		"/feed/",
		"/index.xml",
		"/feed.json",
		"/blog/feed",
		"/blog/rss",
		"/blog/rss.xml",
		"/blog/atom.xml",
		"/blog/feed.xml",
		"/news/rss",
		"/news/feed",
		"/news/rss.xml",
		"/feeds/posts/default",
		"/posts/index.xml",
	}

	for _, endpoint := range endpoints {
		feedURL := fmt.Sprintf("%s%s", baseURL, endpoint)

		articles, err := s.tryFeed(ctx, feedURL)
		if err != nil {
			log.Debug().Err(err).Str("url", feedURL).Msg("Feed endpoint failed")
			continue
		}

		if len(articles) > 0 {
			log.Info().
				Str("endpoint", endpoint).
				Str("url", feedURL).
				Int("articles", len(articles)).
				Msg("Found RSS feed at endpoint")
			return articles, nil
		}
	}

	return nil, nil
}

func (s *RSSEndpointsStep) tryFeed(ctx context.Context, feedURL string) ([]ArticleMetadata, error) {
	resp, err := s.httpClient.Get(ctx, feedURL)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, nil
	}

	feed, err := s.feedParser.ParseString(resp.Text())
	if err != nil {
		return nil, nil
	}

	if len(feed.Items) == 0 {
		return nil, nil
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

	return articles, nil
}
