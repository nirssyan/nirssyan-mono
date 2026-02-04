package http

import (
	"context"
	"sync"

	"golang.org/x/time/rate"
)

type DomainRateLimiter struct {
	limiters    map[string]*rate.Limiter
	mu          sync.RWMutex
	defaultRate rate.Limit
}

func NewDomainRateLimiter(requestsPerSecond float64) *DomainRateLimiter {
	return &DomainRateLimiter{
		limiters:    make(map[string]*rate.Limiter),
		defaultRate: rate.Limit(requestsPerSecond),
	}
}

func (r *DomainRateLimiter) getLimiter(domain string) *rate.Limiter {
	r.mu.RLock()
	limiter, exists := r.limiters[domain]
	r.mu.RUnlock()

	if exists {
		return limiter
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if limiter, exists = r.limiters[domain]; exists {
		return limiter
	}

	limiter = rate.NewLimiter(r.defaultRate, 1)
	r.limiters[domain] = limiter

	return limiter
}

func (r *DomainRateLimiter) Wait(ctx context.Context, domain string) error {
	limiter := r.getLimiter(domain)
	return limiter.Wait(ctx)
}

func (r *DomainRateLimiter) Allow(domain string) bool {
	limiter := r.getLimiter(domain)
	return limiter.Allow()
}
