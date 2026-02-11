package rss

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/mmcdole/gofeed"
	"github.com/rs/zerolog/log"
)

type Parser struct {
	httpClient *http.Client
	feedParser *gofeed.Parser
}

func NewParser(httpClient *http.Client) *Parser {
	return &Parser{
		httpClient: httpClient,
		feedParser: gofeed.NewParser(),
	}
}

type RSSItem struct {
	Title          string
	Link           string
	Description    string
	Content        string
	PubDate        *time.Time
	GUID           string
	EnclosureURL   string
	Images         []string
}

func (p *Parser) ParseFeed(ctx context.Context, feedURL string) ([]RSSItem, error) {
	resp, err := p.httpClient.Get(ctx, feedURL)
	if err != nil {
		return nil, fmt.Errorf("fetch feed: %w", err)
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("feed returned status %d", resp.StatusCode)
	}

	feed, err := p.feedParser.ParseString(resp.Text())
	if err != nil {
		return nil, fmt.Errorf("parse feed: %w", err)
	}

	items := make([]RSSItem, 0, len(feed.Items))

	for _, item := range feed.Items {
		rssItem := p.convertItem(item)
		items = append(items, rssItem)
	}

	log.Debug().
		Str("url", feedURL).
		Int("items", len(items)).
		Msg("Parsed RSS feed")

	return items, nil
}

func (p *Parser) convertItem(item *gofeed.Item) RSSItem {
	rssItem := RSSItem{
		Title:       item.Title,
		Link:        item.Link,
		Description: item.Description,
		GUID:        item.GUID,
	}

	if item.Content != "" {
		rssItem.Content = item.Content
	}

	if item.PublishedParsed != nil {
		rssItem.PubDate = item.PublishedParsed
	} else if item.UpdatedParsed != nil {
		rssItem.PubDate = item.UpdatedParsed
	}

	if len(item.Enclosures) > 0 {
		for _, enc := range item.Enclosures {
			if strings.HasPrefix(enc.Type, "image/") || isImageURL(enc.URL) {
				rssItem.EnclosureURL = enc.URL
				break
			}
		}
	}

	rssItem.Images = p.extractImages(item)

	return rssItem
}

func (p *Parser) extractImages(item *gofeed.Item) []string {
	images := make([]string, 0)
	seen := make(map[string]bool)

	if item.Image != nil && item.Image.URL != "" {
		if !seen[item.Image.URL] {
			seen[item.Image.URL] = true
			images = append(images, item.Image.URL)
		}
	}

	for _, ext := range item.Extensions {
		for _, items := range ext {
			for _, extItem := range items {
				if extItem.Name == "content" || extItem.Name == "thumbnail" {
					if url, ok := extItem.Attrs["url"]; ok && url != "" {
						if isImageURL(url) && !seen[url] {
							seen[url] = true
							images = append(images, url)
						}
					}
				}
			}
		}
	}

	htmlContent := item.Content
	if htmlContent == "" {
		htmlContent = item.Description
	}

	if htmlContent != "" {
		htmlImages := ExtractImagesFromHTML(htmlContent)
		for _, imgURL := range htmlImages {
			if !seen[imgURL] {
				seen[imgURL] = true
				images = append(images, imgURL)
			}
		}
	}

	return images
}

func ExtractImagesFromHTML(html string) []string {
	if html == "" {
		return nil
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil
	}

	images := make([]string, 0)
	seen := make(map[string]bool)

	doc.Find("img").Each(func(_ int, s *goquery.Selection) {
		for _, attr := range []string{"data-src", "data-lazy-src", "data-original", "src"} {
			if imgURL, exists := s.Attr(attr); exists && imgURL != "" {
				if !strings.HasPrefix(imgURL, "data:") && !seen[imgURL] {
					seen[imgURL] = true
					images = append(images, imgURL)
					break
				}
			}
		}

		if srcset, exists := s.Attr("srcset"); exists && srcset != "" {
			if parsedURL := parseSrcsetFirstURL(srcset); parsedURL != "" && !seen[parsedURL] {
				seen[parsedURL] = true
				images = append(images, parsedURL)
			}
		}
	})

	return images
}

func parseSrcsetFirstURL(srcset string) string {
	parts := strings.Split(srcset, ",")
	if len(parts) == 0 {
		return ""
	}

	first := strings.TrimSpace(parts[0])
	tokens := strings.Fields(first)
	if len(tokens) == 0 {
		return ""
	}

	return tokens[0]
}

func isImageURL(urlStr string) bool {
	if urlStr == "" {
		return false
	}

	parsed, err := url.Parse(urlStr)
	if err != nil {
		return false
	}

	path := strings.ToLower(parsed.Path)
	imageExts := []string{".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".bmp"}

	for _, ext := range imageExts {
		if strings.HasSuffix(path, ext) {
			return true
		}
	}

	return false
}

func GenerateUniqueCode(link string) string {
	hash := md5.Sum([]byte(link))
	return hex.EncodeToString(hash[:])
}

func (r RSSItem) ToRawPostData(feedID domain.RawFeed) domain.RawPostCreateData {
	content := r.Content
	if content == "" {
		content = r.Description
	}
	if content == "" {
		content = ""
	}

	if r.Title != "" && !strings.Contains(content, r.Title) {
		content = fmt.Sprintf("**%s**\n\n%s", r.Title, content)
	}

	mediaObjects := make([]domain.MediaObject, 0)
	seenURLs := make(map[string]bool)

	if r.EnclosureURL != "" && !seenURLs[r.EnclosureURL] {
		seenURLs[r.EnclosureURL] = true
		mediaObjects = append(mediaObjects, domain.NewMediaObject(r.EnclosureURL))
	}

	for _, imgURL := range r.Images {
		if !seenURLs[imgURL] {
			seenURLs[imgURL] = true
			mediaObjects = append(mediaObjects, domain.NewMediaObject(imgURL))
		}
	}

	uniqueCode := GenerateUniqueCode(r.Link)

	var title *string
	if r.Title != "" {
		title = &r.Title
	}

	var sourceURL *string
	if r.Link != "" {
		sourceURL = &r.Link
	}

	return domain.RawPostCreateData{
		Content:          content,
		RawFeedID:        feedID.ID,
		MediaObjects:     mediaObjects,
		RPUniqueCode:     uniqueCode,
		Title:            title,
		SourceURL:        sourceURL,
		CreatedAt:        r.PubDate,
		ModerationAction: domain.ModerationActionAllow,
		ModerationLabels: []string{},
		ModerationBlockReasons: []string{},
	}
}
