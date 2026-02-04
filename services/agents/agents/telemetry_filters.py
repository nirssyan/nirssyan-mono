"""OpenTelemetry span filtering for makefeed-processor service."""

from loguru import logger
from opentelemetry.context import Context
from opentelemetry.sdk.trace import ReadableSpan, Span, SpanProcessor
from opentelemetry.trace import SpanKind


class FilteringSpanProcessor(SpanProcessor):
    """SpanProcessor that filters out noisy internal spans."""

    def __init__(
        self,
        wrapped_processor: SpanProcessor,
        filter_httpx_internal: bool = True,
        filter_sql: bool = False,
        filter_health_checks: bool = True,
    ):
        self.wrapped_processor = wrapped_processor
        self.filter_httpx_internal = filter_httpx_internal
        self.filter_sql = filter_sql
        self.filter_health_checks = filter_health_checks
        self.filtered_count = 0
        self.passed_count = 0

    def should_filter_span(self, span: ReadableSpan) -> bool:
        """Determine if a span should be filtered out."""
        span_name = span.name.lower()
        attributes = span.attributes or {}

        if self.filter_health_checks:
            if any(
                endpoint in span_name
                for endpoint in ["/health", "/metrics", "/ready", "/live"]
            ):
                return True

        if self.filter_httpx_internal and span.kind == SpanKind.CLIENT:
            http_method_attr = attributes.get("http.method", "")
            http_method = (
                http_method_attr.upper() if isinstance(http_method_attr, str) else ""
            )
            if http_method == "CONNECT":
                return True

            if span_name in [
                "http get",
                "http post",
                "http put",
                "http delete",
                "http patch",
            ]:
                if "http.url" not in attributes and "http.target" not in attributes:
                    return True

            if span_name == "connect":
                return True

        if self.filter_sql:
            db_system = attributes.get("db.system", "")
            if db_system:
                return True

        return False

    def on_start(self, span: Span, parent_context: Context | None = None) -> None:
        """Called when span starts."""
        self.wrapped_processor.on_start(span, parent_context)

    def on_end(self, span: ReadableSpan) -> None:
        """Called when span ends."""
        if self.should_filter_span(span):
            self.filtered_count += 1
            if self.filtered_count <= 10:
                logger.debug(
                    f"Filtered span: {span.name} "
                    f"(kind={span.kind}, attributes={span.attributes})"
                )
            return

        self.passed_count += 1
        self.wrapped_processor.on_end(span)

    def shutdown(self) -> None:
        """Shutdown the processor."""
        logger.info(
            f"FilteringSpanProcessor stats: "
            f"filtered={self.filtered_count}, passed={self.passed_count}"
        )
        self.wrapped_processor.shutdown()

    def force_flush(self, timeout_millis: int = 30000) -> bool:
        """Force flush the processor."""
        return bool(self.wrapped_processor.force_flush(timeout_millis))
