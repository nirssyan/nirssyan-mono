package observability

import (
	"net/http"
	"strconv"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	feedsPolledTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "feeds_polled_total",
			Help: "Total number of feeds polled",
		},
		[]string{"source", "status"},
	)

	postsCreatedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "posts_created_total",
			Help: "Total number of posts created",
		},
		[]string{"source"},
	)

	natsMessagesPublishedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "nats_messages_published_total",
			Help: "Total number of NATS messages published",
		},
		[]string{"subject"},
	)

	moderationRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "moderation_requests_total",
			Help: "Total number of moderation requests",
		},
		[]string{"status"},
	)

	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests made",
		},
		[]string{"domain", "status"},
	)

	pollDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "poll_duration_seconds",
			Help:    "Duration of poll operations in seconds",
			Buckets: prometheus.ExponentialBuckets(0.1, 2, 10),
		},
		[]string{"source", "tier"},
	)

	contentFetchDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "content_fetch_duration_seconds",
			Help:    "Duration of content fetch operations in seconds",
			Buckets: prometheus.ExponentialBuckets(0.1, 2, 10),
		},
		[]string{"source"},
	)

	discoveryStepDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "discovery_step_duration_seconds",
			Help:    "Duration of discovery steps in seconds",
			Buckets: prometheus.ExponentialBuckets(0.1, 2, 10),
		},
		[]string{"step"},
	)

	telegramFloodWaitTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "telegram_flood_wait_seconds_total",
			Help: "Total seconds spent waiting due to Telegram FloodWait",
		},
	)

	telegramRateMultiplier = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "telegram_rate_multiplier",
			Help: "Current adaptive rate multiplier for Telegram requests",
		},
	)

	telegramMessagesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "telegram_messages_total",
			Help: "Total number of Telegram messages processed",
		},
		[]string{"channel"},
	)
)

func IncFeedsPolled(source, status string) {
	feedsPolledTotal.WithLabelValues(source, status).Inc()
}

func IncPostsCreated(source string, count int) {
	postsCreatedTotal.WithLabelValues(source).Add(float64(count))
}

func IncNATSPublished(subject string) {
	natsMessagesPublishedTotal.WithLabelValues(subject).Inc()
}

func IncModerationRequest(status string) {
	moderationRequestsTotal.WithLabelValues(status).Inc()
}

func IncHTTPRequest(domain string, statusCode int) {
	httpRequestsTotal.WithLabelValues(domain, strconv.Itoa(statusCode)).Inc()
}

func ObservePollDuration(source, tier string, seconds float64) {
	pollDurationSeconds.WithLabelValues(source, tier).Observe(seconds)
}

func ObserveContentFetchDuration(source string, seconds float64) {
	contentFetchDurationSeconds.WithLabelValues(source).Observe(seconds)
}

func ObserveDiscoveryStepDuration(step string, seconds float64) {
	discoveryStepDurationSeconds.WithLabelValues(step).Observe(seconds)
}

func IncTelegramFloodWait(seconds int) {
	telegramFloodWaitTotal.Add(float64(seconds))
}

func SetTelegramRateMultiplier(multiplier float64) {
	telegramRateMultiplier.Set(multiplier)
}

func IncTelegramMessages(channel string, count int) {
	telegramMessagesTotal.WithLabelValues(channel).Add(float64(count))
}

func MetricsHandler() http.Handler {
	return promhttp.Handler()
}
