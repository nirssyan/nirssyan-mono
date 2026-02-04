package discovery

import (
	"context"
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/http"
	"github.com/MargoRSq/infatium-mono/services/go-poller/pkg/observability"
	"github.com/rs/zerolog/log"
)

type ArticleMetadata struct {
	URL           string
	Title         string
	PublishedDate string
	Source        string
	Content       string
	Summary       string
	MediaURLs     []string
}

type DiscoveryStep interface {
	Name() string
	Execute(ctx context.Context, baseURL string) ([]ArticleMetadata, error)
	Priority() int
}

type Pipeline struct {
	steps      []DiscoveryStep
	httpClient *http.Client
}

func NewPipeline(httpClient *http.Client) *Pipeline {
	p := &Pipeline{
		httpClient: httpClient,
	}

	p.steps = []DiscoveryStep{
		NewRSSCheckStep(httpClient),
		NewRSSEndpointsStep(httpClient),
		NewSitemapStep(httpClient),
		NewHTMLParserStep(httpClient),
		NewTrafilaturaStep(httpClient),
	}

	return p
}

type DiscoveryResult struct {
	Articles   []ArticleMetadata
	SourceType string
	FeedURL    string
}

func (p *Pipeline) Discover(ctx context.Context, baseURL string, maxArticles int, knownSourceType string) (*DiscoveryResult, error) {
	if knownSourceType != "" {
		return p.discoverWithKnownType(ctx, baseURL, maxArticles, knownSourceType)
	}

	for _, step := range p.steps {
		startTime := time.Now()

		articles, err := step.Execute(ctx, baseURL)
		duration := time.Since(startTime).Seconds()
		observability.ObserveDiscoveryStepDuration(step.Name(), duration)

		if err != nil {
			log.Debug().
				Err(err).
				Str("step", step.Name()).
				Str("url", baseURL).
				Msg("Discovery step failed")
			continue
		}

		if len(articles) > 0 {
			log.Info().
				Str("step", step.Name()).
				Str("url", baseURL).
				Int("articles", len(articles)).
				Float64("duration", duration).
				Msg("Discovery step succeeded")

			if len(articles) > maxArticles {
				articles = articles[:maxArticles]
			}

			feedURL := ""
			if rssStep, ok := step.(*RSSCheckStep); ok {
				feedURL = rssStep.lastFeedURL
			} else if endpointsStep, ok := step.(*RSSEndpointsStep); ok {
				feedURL = endpointsStep.lastFeedURL
			}

			return &DiscoveryResult{
				Articles:   articles,
				SourceType: step.Name(),
				FeedURL:    feedURL,
			}, nil
		}
	}

	log.Warn().Str("url", baseURL).Msg("No articles found by any discovery method")
	return &DiscoveryResult{
		Articles:   nil,
		SourceType: "",
	}, nil
}

func (p *Pipeline) discoverWithKnownType(ctx context.Context, baseURL string, maxArticles int, sourceType string) (*DiscoveryResult, error) {
	for _, step := range p.steps {
		if step.Name() != sourceType {
			continue
		}

		startTime := time.Now()
		articles, err := step.Execute(ctx, baseURL)
		duration := time.Since(startTime).Seconds()
		observability.ObserveDiscoveryStepDuration(step.Name(), duration)

		if err != nil {
			return nil, err
		}

		if len(articles) > maxArticles {
			articles = articles[:maxArticles]
		}

		feedURL := ""
		if rssStep, ok := step.(*RSSCheckStep); ok {
			feedURL = rssStep.lastFeedURL
		} else if endpointsStep, ok := step.(*RSSEndpointsStep); ok {
			feedURL = endpointsStep.lastFeedURL
		}

		return &DiscoveryResult{
			Articles:   articles,
			SourceType: sourceType,
			FeedURL:    feedURL,
		}, nil
	}

	return p.Discover(ctx, baseURL, maxArticles, "")
}
