package otel

import (
	"context"

	"github.com/rs/zerolog/log"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"

	"github.com/MargoRSq/infatium-mono/services/go-integrations/internal/config"
)

func InitTracing(ctx context.Context, cfg *config.Config) (func(), error) {
	if !cfg.OTelEnabled {
		log.Info().Msg("OpenTelemetry tracing disabled")
		return func() {}, nil
	}

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(cfg.OTelExporterEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(cfg.OTelServiceName),
			semconv.DeploymentEnvironment(cfg.OTelEnvironment),
		),
	)
	if err != nil {
		return nil, err
	}

	tp := trace.NewTracerProvider(
		trace.WithBatcher(exporter),
		trace.WithResource(res),
		trace.WithSampler(trace.AlwaysSample()),
	)

	otel.SetTracerProvider(tp)

	log.Info().
		Str("endpoint", cfg.OTelExporterEndpoint).
		Str("service", cfg.OTelServiceName).
		Msg("OpenTelemetry tracing initialized")

	shutdown := func() {
		if err := tp.Shutdown(context.Background()); err != nil {
			log.Error().Err(err).Msg("Error shutting down tracer provider")
		}
	}

	return shutdown, nil
}
