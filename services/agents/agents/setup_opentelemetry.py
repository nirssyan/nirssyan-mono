"""OpenTelemetry initialization for makefeed-agents service."""

from loguru import logger
from opentelemetry import metrics, trace
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from .config import settings
from .telemetry_filters import FilteringSpanProcessor


def setup_opentelemetry() -> TracerProvider | None:
    """Initialize OpenTelemetry tracing and metrics.

    Returns:
        TracerProvider if enabled, None otherwise.
    """
    if not settings.otel_enabled:
        logger.info("OpenTelemetry is disabled")
        return None

    try:
        resource = Resource(
            attributes={
                SERVICE_NAME: settings.otel_service_name,
                "deployment.environment": settings.otel_deployment_environment,
                "service.version": "1.0.0",
            }
        )

        # Tracing setup
        trace_provider = TracerProvider(resource=resource)

        if settings.otel_exporter_otlp_protocol == "http/protobuf":
            from opentelemetry.exporter.otlp.proto.http.trace_exporter import (
                OTLPSpanExporter,
            )

            otlp_trace_exporter = OTLPSpanExporter(
                endpoint=settings.otel_exporter_otlp_endpoint,
            )
        else:
            from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
                OTLPSpanExporter,
            )

            otlp_trace_exporter = OTLPSpanExporter(
                endpoint=settings.otel_exporter_otlp_endpoint,
                insecure=settings.otel_exporter_otlp_insecure,
            )

        otlp_batch_processor = BatchSpanProcessor(otlp_trace_exporter)
        otlp_filtering_processor = FilteringSpanProcessor(
            wrapped_processor=otlp_batch_processor,
            filter_httpx_internal=not settings.otel_trace_httpx_enabled,
            filter_sql=not settings.otel_trace_sql_enabled,
            filter_health_checks=True,
        )
        trace_provider.add_span_processor(otlp_filtering_processor)

        logger.info(
            f"OpenTelemetry tracing initialized. "
            f"Endpoint: {settings.otel_exporter_otlp_endpoint}"
        )

        trace.set_tracer_provider(trace_provider)

        # Metrics setup - PrometheusMetricReader for Prometheus scraping
        # This is preferred over OTLP because our infrastructure (Grafana Agent)
        # doesn't support OTLP metrics receiver, only scraping /metrics endpoints
        from opentelemetry.exporter.prometheus import PrometheusMetricReader
        from prometheus_client import start_http_server

        prometheus_port = settings.otel_prometheus_port

        # Start Prometheus HTTP server for /metrics endpoint
        start_http_server(port=prometheus_port, addr="0.0.0.0")
        logger.info(f"Prometheus HTTP server started on port {prometheus_port}")

        metric_reader = PrometheusMetricReader()

        logger.info(
            f"OpenTelemetry metrics initialized with Prometheus exporter on port {prometheus_port}"
        )

        meter_provider = MeterProvider(
            resource=resource, metric_readers=[metric_reader]
        )
        metrics.set_meter_provider(meter_provider)

        return trace_provider

    except Exception as e:
        logger.error(f"Failed to initialize OpenTelemetry: {e}", exc_info=True)
        return None
