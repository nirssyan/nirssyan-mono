package observability

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration in seconds",
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
	}, []string{"method", "path", "status_code"})

	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total number of HTTP requests",
	}, []string{"method", "path", "status_code"})

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

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.statusCode = code
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hj, ok := r.ResponseWriter.(http.Hijacker); ok {
		return hj.Hijack()
	}
	return nil, nil, fmt.Errorf("http.Hijacker not supported")
}

func HTTPMetrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(rec, r)

		path := r.URL.Path
		if rctx := chi.RouteContext(r.Context()); rctx != nil {
			if pattern := rctx.RoutePattern(); pattern != "" {
				path = pattern
			}
		}

		status := strconv.Itoa(rec.statusCode)
		duration := time.Since(start).Seconds()

		httpRequestDuration.WithLabelValues(r.Method, path, status).Observe(duration)
		httpRequestsTotal.WithLabelValues(r.Method, path, status).Inc()
	})
}

func MetricsHandler() http.Handler {
	return promhttp.Handler()
}
