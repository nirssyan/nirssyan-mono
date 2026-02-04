package http

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/rs/zerolog/log"
)

type ClientConfig struct {
	Timeout        time.Duration
	MaxRetries     int
	MinDelay       time.Duration
	MaxDelay       time.Duration
	CacheEnabled   bool
	CacheTTLHours  int
	RequestsPerSec float64
}

type Client struct {
	httpClient  *http.Client
	rateLimiter *DomainRateLimiter
	cache       *Cache
	config      ClientConfig
	userAgents  []string
}

func NewClient(cfg ClientConfig) *Client {
	if cfg.Timeout == 0 {
		cfg.Timeout = 30 * time.Second
	}
	if cfg.MaxRetries == 0 {
		cfg.MaxRetries = 3
	}
	if cfg.MinDelay == 0 {
		cfg.MinDelay = 1 * time.Second
	}
	if cfg.MaxDelay == 0 {
		cfg.MaxDelay = 3 * time.Second
	}
	if cfg.RequestsPerSec == 0 {
		cfg.RequestsPerSec = 0.5
	}

	c := &Client{
		httpClient: &http.Client{
			Timeout: cfg.Timeout,
			Transport: &http.Transport{
				MaxIdleConns:        10,
				MaxIdleConnsPerHost: 10,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		rateLimiter: NewDomainRateLimiter(cfg.RequestsPerSec),
		config:      cfg,
		userAgents: []string{
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
			"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
		},
	}

	if cfg.CacheEnabled {
		c.cache = NewCache(time.Duration(cfg.CacheTTLHours) * time.Hour)
	}

	return c
}

func (c *Client) Get(ctx context.Context, targetURL string) (*Response, error) {
	parsedURL, err := url.Parse(targetURL)
	if err != nil {
		return nil, fmt.Errorf("parse url: %w", err)
	}

	domain := parsedURL.Host

	if c.cache != nil {
		if cached, ok := c.cache.Get(targetURL); ok {
			log.Debug().Str("url", targetURL).Msg("Cache hit")
			return &Response{
				StatusCode: 200,
				Body:       []byte(cached),
				FromCache:  true,
			}, nil
		}
	}

	if err := c.rateLimiter.Wait(ctx, domain); err != nil {
		return nil, fmt.Errorf("rate limit: %w", err)
	}

	jitter := time.Duration(rand.Intn(int(c.config.MaxDelay-c.config.MinDelay))) + c.config.MinDelay
	time.Sleep(jitter)

	var lastErr error
	for attempt := 0; attempt < c.config.MaxRetries; attempt++ {
		resp, err := c.doRequest(ctx, targetURL)
		if err == nil {
			observability.IncHTTPRequest(domain, resp.StatusCode)

			if resp.StatusCode == 200 && c.cache != nil {
				c.cache.Set(targetURL, string(resp.Body))
			}

			return resp, nil
		}

		lastErr = err
		log.Warn().
			Err(err).
			Str("url", targetURL).
			Int("attempt", attempt+1).
			Msg("Request failed, retrying")

		backoff := time.Duration(1<<attempt) * time.Second
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff):
		}
	}

	return nil, fmt.Errorf("all retries failed: %w", lastErr)
}

func (c *Client) doRequest(ctx context.Context, targetURL string) (*Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, targetURL, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", c.userAgents[rand.Intn(len(c.userAgents))])
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.5")
	req.Header.Set("Accept-Encoding", "gzip, deflate")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	return &Response{
		StatusCode: resp.StatusCode,
		Body:       body,
		Headers:    resp.Header,
	}, nil
}

func (c *Client) Head(ctx context.Context, targetURL string) (*Response, error) {
	parsedURL, err := url.Parse(targetURL)
	if err != nil {
		return nil, fmt.Errorf("parse url: %w", err)
	}

	domain := parsedURL.Host

	if err := c.rateLimiter.Wait(ctx, domain); err != nil {
		return nil, fmt.Errorf("rate limit: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodHead, targetURL, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", c.userAgents[rand.Intn(len(c.userAgents))])

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	observability.IncHTTPRequest(domain, resp.StatusCode)

	return &Response{
		StatusCode: resp.StatusCode,
		Headers:    resp.Header,
	}, nil
}

type Response struct {
	StatusCode int
	Body       []byte
	Headers    http.Header
	FromCache  bool
}

func (r *Response) Text() string {
	return string(r.Body)
}
