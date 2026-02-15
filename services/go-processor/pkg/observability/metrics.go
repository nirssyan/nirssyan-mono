package observability

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	natsConsumed = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "nats_messages_consumed_total",
		Help: "Total number of NATS messages consumed",
	}, []string{"subject"})

	natsAcked = promauto.NewCounter(prometheus.CounterOpts{
		Name: "nats_messages_acked_total",
		Help: "Total number of NATS messages acknowledged",
	})

	natsNacked = promauto.NewCounter(prometheus.CounterOpts{
		Name: "nats_messages_nacked_total",
		Help: "Total number of NATS messages not acknowledged",
	})

	postsCreated = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "posts_created_total",
		Help: "Total number of posts created",
	}, []string{"feed_type"})

	agentRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "agent_requests_total",
		Help: "Total number of agent RPC requests",
	}, []string{"agent"})

	agentRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "agent_request_duration_seconds",
		Help:    "Duration of agent RPC requests",
		Buckets: prometheus.DefBuckets,
	}, []string{"agent"})

	processingDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "processing_duration_seconds",
		Help:    "Duration of message processing",
		Buckets: prometheus.DefBuckets,
	}, []string{"event_type"})

	cacheHits = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "cache_hits_total",
		Help: "Total number of cache hits",
	}, []string{"cache"})

	cacheMisses = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "cache_misses_total",
		Help: "Total number of cache misses",
	}, []string{"cache"})
)

func IncNATSConsumed(subject string) {
	natsConsumed.WithLabelValues(subject).Inc()
}

func IncNATSAcked() {
	natsAcked.Inc()
}

func IncNATSNacked() {
	natsNacked.Inc()
}

func IncPostsCreated(feedType string) {
	postsCreated.WithLabelValues(feedType).Inc()
}

func IncAgentRequests(agent string) {
	agentRequests.WithLabelValues(agent).Inc()
}

func ObserveAgentRequestDuration(agent string, seconds float64) {
	agentRequestDuration.WithLabelValues(agent).Observe(seconds)
}

func ObserveProcessingDuration(eventType string, seconds float64) {
	processingDuration.WithLabelValues(eventType).Observe(seconds)
}

func IncCacheHit(cache string) {
	cacheHits.WithLabelValues(cache).Inc()
}

func IncCacheMiss(cache string) {
	cacheMisses.WithLabelValues(cache).Inc()
}

func MetricsHandler() http.Handler {
	return promhttp.Handler()
}
