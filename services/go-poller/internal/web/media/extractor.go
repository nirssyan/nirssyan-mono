package media

import (
	"net/url"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

const (
	MinContentImageWidth  = 400
	MinContentImageHeight = 300
)

func ExtractMediaURLs(html, baseURL string, preferHighQuality bool) []string {
	if html == "" {
		return nil
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil
	}

	mediaURLs := make([]string, 0)
	seen := make(map[string]bool)

	doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
		if srcset, exists := sel.Attr("srcset"); exists {
			parsed := parseSrcset(srcset)
			if len(parsed) > 0 {
				if preferHighQuality {
					url := resolveURL(baseURL, parsed[0].URL)
					if url != "" && !seen[url] {
						seen[url] = true
						mediaURLs = append(mediaURLs, url)
					}
				} else {
					for _, item := range parsed {
						url := resolveURL(baseURL, item.URL)
						if url != "" && !seen[url] {
							seen[url] = true
							mediaURLs = append(mediaURLs, url)
						}
					}
				}
			}
		}

		for _, attr := range []string{"src", "data-src", "data-lazy-src", "data-original", "data-bg", "data-background", "data-image", "data-full-src"} {
			if imgURL, exists := sel.Attr(attr); exists && imgURL != "" {
				resolved := resolveURL(baseURL, imgURL)
				if resolved != "" && !seen[resolved] {
					seen[resolved] = true
					mediaURLs = append(mediaURLs, resolved)
					break
				}
			}
		}
	})

	doc.Find("source").Each(func(_ int, sel *goquery.Selection) {
		if srcset, exists := sel.Attr("srcset"); exists {
			parsed := parseSrcset(srcset)
			if len(parsed) > 0 {
				if preferHighQuality {
					url := resolveURL(baseURL, parsed[0].URL)
					if url != "" && !seen[url] {
						seen[url] = true
						mediaURLs = append(mediaURLs, url)
					}
				}
			}
		}

		if src, exists := sel.Attr("src"); exists && src != "" {
			resolved := resolveURL(baseURL, src)
			if resolved != "" && !seen[resolved] {
				seen[resolved] = true
				mediaURLs = append(mediaURLs, resolved)
			}
		}
	})

	doc.Find("video").Each(func(_ int, sel *goquery.Selection) {
		if src, exists := sel.Attr("src"); exists && src != "" {
			resolved := resolveURL(baseURL, src)
			if resolved != "" && !seen[resolved] {
				seen[resolved] = true
				mediaURLs = append(mediaURLs, resolved)
			}
		}

		if poster, exists := sel.Attr("poster"); exists && poster != "" {
			resolved := resolveURL(baseURL, poster)
			if resolved != "" && !seen[resolved] {
				seen[resolved] = true
				mediaURLs = append(mediaURLs, resolved)
			}
		}

		sel.Find("source").Each(func(_ int, source *goquery.Selection) {
			if src, exists := source.Attr("src"); exists && src != "" {
				resolved := resolveURL(baseURL, src)
				if resolved != "" && !seen[resolved] {
					seen[resolved] = true
					mediaURLs = append(mediaURLs, resolved)
				}
			}
		})
	})

	ogTags := []struct{ attr, value string }{
		{"property", "og:image"},
		{"property", "og:video"},
		{"property", "og:video:url"},
		{"name", "twitter:image"},
		{"name", "twitter:player:stream"},
	}

	for _, tag := range ogTags {
		doc.Find("meta[" + tag.attr + "=\"" + tag.value + "\"]").Each(func(_ int, sel *goquery.Selection) {
			if content, exists := sel.Attr("content"); exists && content != "" {
				resolved := resolveURL(baseURL, content)
				if resolved != "" && !seen[resolved] {
					seen[resolved] = true
					mediaURLs = append(mediaURLs, resolved)
				}
			}
		})
	}

	mediaURLs = FilterLogosAndIcons(mediaURLs, doc)
	mediaURLs = DeduplicateMediaURLs(mediaURLs, preferHighQuality)

	return mediaURLs
}

func resolveURL(baseURL, href string) string {
	if href == "" {
		return ""
	}

	if strings.HasPrefix(href, "data:") {
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

type srcsetItem struct {
	URL   string
	Width int
}

func parseSrcset(srcset string) []srcsetItem {
	if srcset == "" {
		return nil
	}

	parts := strings.Split(srcset, ",")
	items := make([]srcsetItem, 0, len(parts))

	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}

		tokens := strings.Fields(part)
		if len(tokens) == 0 {
			continue
		}

		item := srcsetItem{URL: tokens[0]}

		if len(tokens) > 1 {
			desc := tokens[1]
			if strings.HasSuffix(desc, "w") {
				var width int
				if _, err := strings.CutSuffix(desc, "w"); err {
					item.Width = width
				}
			}
		}

		items = append(items, item)
	}

	for i := 0; i < len(items)-1; i++ {
		for j := i + 1; j < len(items); j++ {
			if items[j].Width > items[i].Width {
				items[i], items[j] = items[j], items[i]
			}
		}
	}

	return items
}

var widthRegex = regexp.MustCompile(`^(\d+)w$`)
