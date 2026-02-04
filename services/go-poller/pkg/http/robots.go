package http

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"sync"
)

type RobotsChecker struct {
	client *Client
	cache  map[string]*robotsRules
	mu     sync.RWMutex
}

type robotsRules struct {
	disallowedPaths []string
	allowedPaths    []string
	crawlDelay      int
}

func NewRobotsChecker(client *Client) *RobotsChecker {
	return &RobotsChecker{
		client: client,
		cache:  make(map[string]*robotsRules),
	}
}

func (r *RobotsChecker) IsAllowed(ctx context.Context, targetURL string, userAgent string) (bool, error) {
	parsedURL, err := url.Parse(targetURL)
	if err != nil {
		return true, nil
	}

	domain := parsedURL.Host
	rules, err := r.getRules(ctx, domain, parsedURL.Scheme)
	if err != nil {
		return true, nil
	}

	if rules == nil {
		return true, nil
	}

	path := parsedURL.Path
	if path == "" {
		path = "/"
	}

	for _, allowed := range rules.allowedPaths {
		if strings.HasPrefix(path, allowed) {
			return true, nil
		}
	}

	for _, disallowed := range rules.disallowedPaths {
		if strings.HasPrefix(path, disallowed) {
			return false, nil
		}
	}

	return true, nil
}

func (r *RobotsChecker) GetCrawlDelay(ctx context.Context, domain, scheme string) int {
	rules, err := r.getRules(ctx, domain, scheme)
	if err != nil || rules == nil {
		return 0
	}
	return rules.crawlDelay
}

func (r *RobotsChecker) getRules(ctx context.Context, domain, scheme string) (*robotsRules, error) {
	r.mu.RLock()
	rules, exists := r.cache[domain]
	r.mu.RUnlock()

	if exists {
		return rules, nil
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if rules, exists = r.cache[domain]; exists {
		return rules, nil
	}

	robotsURL := fmt.Sprintf("%s://%s/robots.txt", scheme, domain)
	resp, err := r.client.Get(ctx, robotsURL)
	if err != nil || resp.StatusCode != 200 {
		r.cache[domain] = nil
		return nil, nil
	}

	rules = parseRobotsTxt(resp.Text())
	r.cache[domain] = rules

	return rules, nil
}

func parseRobotsTxt(content string) *robotsRules {
	rules := &robotsRules{}
	lines := strings.Split(content, "\n")

	inUserAgentBlock := false
	isRelevantAgent := false

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}

		directive := strings.ToLower(strings.TrimSpace(parts[0]))
		value := strings.TrimSpace(parts[1])

		switch directive {
		case "user-agent":
			inUserAgentBlock = true
			isRelevantAgent = value == "*" || strings.Contains(strings.ToLower(value), "bot")
		case "disallow":
			if inUserAgentBlock && isRelevantAgent && value != "" {
				rules.disallowedPaths = append(rules.disallowedPaths, value)
			}
		case "allow":
			if inUserAgentBlock && isRelevantAgent && value != "" {
				rules.allowedPaths = append(rules.allowedPaths, value)
			}
		case "crawl-delay":
			if inUserAgentBlock && isRelevantAgent {
				var delay int
				fmt.Sscanf(value, "%d", &delay)
				if delay > rules.crawlDelay {
					rules.crawlDelay = delay
				}
			}
		}
	}

	return rules
}
