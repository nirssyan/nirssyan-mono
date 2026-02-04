package media

import (
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

var (
	excludeURLPatterns = []string{
		"/logo/",
		"/icon/",
		"/favicon/",
		"/thumb/",
		"/profile/",
		"/avatar/",
		"/widget/",
		"/badge/",
		"-logo.",
		"-icon.",
		"-favicon.",
		"_logo.",
		"_icon.",
		"/assets/icons/",
		"/static/icons/",
		"/images/icons/",
	}

	excludeFilePrefixes = []string{
		"logo",
		"icon",
		"favicon",
		"avatar",
		"profile",
		"badge",
	}

	excludeClassKeywords = []string{
		"logo",
		"icon",
		"favicon",
		"avatar",
		"profile",
		"brand",
		"widget",
		"sidebar",
		"nav-",
		"menu-",
		"header-",
		"footer-",
	}

	excludeParentTags = []string{
		"header",
		"nav",
		"footer",
		"aside",
	}

	contentAreaTags = []string{
		"article",
		"main",
	}

	contentAreaClasses = []string{
		"content",
		"post",
		"article",
		"entry",
		"body",
	}
)

func IsLikelyContentImage(urlStr string) bool {
	urlLower := strings.ToLower(urlStr)

	for _, pattern := range excludeURLPatterns {
		if strings.Contains(urlLower, pattern) {
			return false
		}
	}

	if strings.HasSuffix(urlLower, ".ico") {
		return false
	}

	parsed, err := url.Parse(urlLower)
	if err != nil {
		return true
	}

	pathParts := strings.Split(parsed.Path, "/")
	if len(pathParts) > 0 {
		filename := pathParts[len(pathParts)-1]
		for _, prefix := range excludeFilePrefixes {
			if strings.HasPrefix(filename, prefix) {
				return false
			}
		}
	}

	return true
}

func ShouldIncludeImage(sel *goquery.Selection, imgURL string) bool {
	if widthStr, exists := sel.Attr("width"); exists {
		if heightStr, exists := sel.Attr("height"); exists {
			width, wErr := strconv.Atoi(widthStr)
			height, hErr := strconv.Atoi(heightStr)
			if wErr == nil && hErr == nil {
				if width < MinContentImageWidth || height < MinContentImageHeight {
					return false
				}
			}
		}
	}

	classAttr, _ := sel.Attr("class")
	idAttr, _ := sel.Attr("id")
	combined := strings.ToLower(classAttr + " " + idAttr)

	for _, keyword := range excludeClassKeywords {
		if strings.Contains(combined, keyword) {
			return false
		}
	}

	altAttr, _ := sel.Attr("alt")
	altLower := strings.ToLower(altAttr)
	for _, keyword := range []string{"logo", "icon", "avatar"} {
		if strings.Contains(altLower, keyword) {
			return false
		}
	}

	return true
}

func IsInContentArea(sel *goquery.Selection) bool {
	parent := sel.Parent()

	for parent.Length() > 0 {
		tagName := goquery.NodeName(parent)

		for _, excludeTag := range excludeParentTags {
			if tagName == excludeTag {
				return false
			}
		}

		for _, contentTag := range contentAreaTags {
			if tagName == contentTag {
				return true
			}
		}

		classAttr, _ := parent.Attr("class")
		classLower := strings.ToLower(classAttr)

		for _, area := range []string{"sidebar", "widget", "header", "footer", "nav"} {
			if strings.Contains(classLower, area) {
				return false
			}
		}

		for _, area := range contentAreaClasses {
			if strings.Contains(classLower, area) {
				return true
			}
		}

		parent = parent.Parent()
	}

	return true
}

func FilterLogosAndIcons(urls []string, doc *goquery.Document) []string {
	filtered := make([]string, 0)

	urlPass1 := make([]string, 0)
	for _, url := range urls {
		if IsLikelyContentImage(url) {
			urlPass1 = append(urlPass1, url)
		}
	}

	if doc == nil {
		return urlPass1
	}

	for _, imgURL := range urlPass1 {
		imgFound := false

		doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
			if imgFound {
				return
			}

			for _, attr := range []string{"src", "data-src", "data-lazy-src", "data-original"} {
				if src, exists := sel.Attr(attr); exists {
					if src == imgURL || strings.HasSuffix(imgURL, src) || strings.HasSuffix(src, imgURL) {
						imgFound = true
						if ShouldIncludeImage(sel, imgURL) && IsInContentArea(sel) {
							filtered = append(filtered, imgURL)
						}
						return
					}
				}
			}
		})

		if !imgFound {
			filtered = append(filtered, imgURL)
		}
	}

	return filtered
}

func DeduplicateMediaURLs(urls []string, preferHighQuality bool) []string {
	if len(urls) == 0 {
		return nil
	}

	grouped := make(map[string][]string)

	for _, url := range urls {
		key := extractFilenameKey(url)
		grouped[key] = append(grouped[key], url)
	}

	result := make([]string, 0)

	for _, group := range grouped {
		if preferHighQuality && len(group) > 1 {
			best := group[0]
			bestPriority := getMediaQualityPriority(best)

			for _, url := range group[1:] {
				priority := getMediaQualityPriority(url)
				if priority > bestPriority {
					best = url
					bestPriority = priority
				}
			}
			result = append(result, best)
		} else {
			result = append(result, group[0])
		}
	}

	return result
}

var sizePatternRegex = regexp.MustCompile(`[-_]\d+x\d+`)
var qualityPatternRegex = regexp.MustCompile(`[-_](thumb|small|medium|large|full|original)`)

func extractFilenameKey(urlStr string) string {
	parsed, err := url.Parse(urlStr)
	if err != nil {
		return strings.ToLower(urlStr)
	}

	path := parsed.Path

	pathParts := strings.Split(path, "/")
	if len(pathParts) == 0 {
		return strings.ToLower(urlStr)
	}

	filename := pathParts[len(pathParts)-1]

	if idx := strings.Index(filename, "?"); idx != -1 {
		filename = filename[:idx]
	}

	filename = sizePatternRegex.ReplaceAllString(filename, "")
	filename = qualityPatternRegex.ReplaceAllString(filename, "")

	return strings.ToLower(filename)
}

var qualityPatterns = map[string]int{
	"original":  100,
	"full":      95,
	"large":     90,
	"big":       85,
	"medium":    70,
	"med":       70,
	"small":     50,
	"thumb":     30,
	"thumbnail": 30,
	"icon":      20,
}

func getMediaQualityPriority(urlStr string) int {
	urlLower := strings.ToLower(urlStr)

	for pattern, priority := range qualityPatterns {
		if strings.Contains(urlLower, "/"+pattern+"/") ||
			strings.Contains(urlLower, "-"+pattern) ||
			strings.Contains(urlLower, "_"+pattern) {
			return priority
		}
	}

	return 60
}
