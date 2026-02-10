package scrapers

import (
	"context"
	"time"

	"github.com/rs/zerolog/log"
)

type Subscription struct {
	ID        string
	VendorID  int
	ModelName string
	LastScrapedAt *time.Time
}

type Post struct {
	Hash        string
	Title       string
	Description string
	Link        string
	PubDate     time.Time
	Extra       map[string]any
}

type Scraper interface {
	Name() string
	Scrape(ctx context.Context, sub *Subscription) ([]Post, error)
	SyncCatalog(ctx context.Context) error
}

type Registry struct {
	scrapers map[string]Scraper
}

func NewRegistry() *Registry {
	return &Registry{
		scrapers: make(map[string]Scraper),
	}
}

func (r *Registry) Register(s Scraper) {
	r.scrapers[s.Name()] = s
	log.Info().Str("scraper", s.Name()).Msg("Scraper registered")
}

func (r *Registry) Get(name string) (Scraper, bool) {
	s, ok := r.scrapers[name]
	return s, ok
}

func (r *Registry) All() []Scraper {
	result := make([]Scraper, 0, len(r.scrapers))
	for _, s := range r.scrapers {
		result = append(result, s)
	}
	return result
}
