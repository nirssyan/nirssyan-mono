package otel

import (
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/zerolog/log"
)

var (
	WebhooksReceived = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "webhooks_received_total",
			Help: "Total webhooks received by source",
		},
		[]string{"source"},
	)

	WebhooksProcessed = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "webhooks_processed_total",
			Help: "Total webhooks processed by source and status",
		},
		[]string{"source", "status"},
	)

	TelegramNotificationsSent = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "telegram_notifications_sent_total",
			Help: "Total Telegram notifications sent by status",
		},
		[]string{"status"},
	)

	WebhookProcessingDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "webhook_processing_duration_seconds",
			Help:    "Webhook processing duration in seconds",
			Buckets: []float64{0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5},
		},
		[]string{"source"},
	)
)

func init() {
	prometheus.MustRegister(WebhooksReceived)
	prometheus.MustRegister(WebhooksProcessed)
	prometheus.MustRegister(TelegramNotificationsSent)
	prometheus.MustRegister(WebhookProcessingDuration)
}

func StartMetricsServer(port int) {
	addr := fmt.Sprintf(":%d", port)
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	go func() {
		log.Info().Str("addr", addr).Msg("Starting Prometheus metrics server")
		if err := http.ListenAndServe(addr, mux); err != nil {
			log.Error().Err(err).Msg("Metrics server error")
		}
	}()
}

func IncrementWebhooksReceived(source string) {
	WebhooksReceived.WithLabelValues(source).Inc()
}

func IncrementWebhooksProcessed(source, status string) {
	WebhooksProcessed.WithLabelValues(source, status).Inc()
}

func IncrementTelegramNotifications(status string) {
	TelegramNotificationsSent.WithLabelValues(status).Inc()
}

func ObserveWebhookDuration(source string, seconds float64) {
	WebhookProcessingDuration.WithLabelValues(source).Observe(seconds)
}
