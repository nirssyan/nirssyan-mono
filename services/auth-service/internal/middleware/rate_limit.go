package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/rs/zerolog"
)

type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	limit    int
	window   time.Duration
	logger   zerolog.Logger
}

type visitor struct {
	count    int
	lastSeen time.Time
}

func NewRateLimiter(limit int, window time.Duration, logger zerolog.Logger) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*visitor),
		limit:    limit,
		window:   window,
		logger:   logger,
	}

	go rl.cleanup()

	return rl
}

func (rl *RateLimiter) cleanup() {
	for {
		time.Sleep(time.Minute)
		rl.mu.Lock()
		for ip, v := range rl.visitors {
			if time.Since(v.lastSeen) > rl.window {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}

func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	if !exists {
		rl.visitors[ip] = &visitor{count: 1, lastSeen: time.Now()}
		return true
	}

	if time.Since(v.lastSeen) > rl.window {
		v.count = 1
		v.lastSeen = time.Now()
		return true
	}

	if v.count >= rl.limit {
		return false
	}

	v.count++
	v.lastSeen = time.Now()
	return true
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)

		if !rl.Allow(ip) {
			rl.logger.Warn().
				Str("ip", ip).
				Str("path", r.URL.Path).
				Msg("rate limit exceeded")

			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", "60")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"rate_limit_exceeded","message":"Too many requests"}`))
			return
		}

		next.ServeHTTP(w, r)
	})
}

func getClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return xff
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	return r.RemoteAddr
}

type EndpointRateLimiters struct {
	limiters map[string]*RateLimiter
	logger   zerolog.Logger
}

func NewEndpointRateLimiters(logger zerolog.Logger) *EndpointRateLimiters {
	return &EndpointRateLimiters{
		limiters: map[string]*RateLimiter{
			"/auth/google":     NewRateLimiter(10, time.Minute, logger),
			"/auth/apple":      NewRateLimiter(10, time.Minute, logger),
			"/auth/magic-link": NewRateLimiter(3, time.Minute, logger),
			"/auth/verify":     NewRateLimiter(10, time.Minute, logger),
			"/auth/refresh":    NewRateLimiter(20, time.Minute, logger),
			"/auth/logout":     NewRateLimiter(10, time.Minute, logger),
		},
		logger: logger,
	}
}

func (erl *EndpointRateLimiters) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		limiter, exists := erl.limiters[r.URL.Path]
		if !exists {
			next.ServeHTTP(w, r)
			return
		}

		limiter.Middleware(next).ServeHTTP(w, r)
	})
}
