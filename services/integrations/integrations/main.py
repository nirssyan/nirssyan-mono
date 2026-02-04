"""Main entrypoint for makefeed-integrations service.

This service handles external integrations and webhooks:
- App Store Connect webhooks (build status, TestFlight, review)
- Future: RuStore webhooks, Google Play webhooks, etc.
"""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import uvicorn
from litestar import Litestar
from litestar.di import Provide
from loguru import logger

from shared.setup_logging import setup_loguru, setup_sentry_logging
from shared.setup_sentry import setup_sentry

from .config import settings
from .controllers import (
    AppStoreWebhookController,
    GlitchTipWebhookController,
    HealthController,
    SentryWebhookController,
)
from .services import (
    AppStoreWebhookService,
    GlitchTipWebhookService,
    SentryWebhookService,
)


def provide_appstore_webhook_service() -> AppStoreWebhookService:
    """Provide App Store webhook service."""
    return AppStoreWebhookService()


def provide_sentry_webhook_service() -> SentryWebhookService:
    """Provide Sentry webhook service."""
    return SentryWebhookService()


def provide_glitchtip_webhook_service() -> GlitchTipWebhookService:
    """Provide GlitchTip webhook service."""
    return GlitchTipWebhookService()


@asynccontextmanager
async def lifespan(_app: Litestar) -> AsyncGenerator[None, None]:
    """Application lifespan manager."""
    setup_loguru("makefeed-integrations", debug=settings.debug)
    setup_sentry(settings)
    setup_sentry_logging(settings.sentry_enabled, settings.debug)
    logger.info("Starting makefeed-integrations service...")
    setup_otel()
    logger.info(f"makefeed-integrations listening on {settings.host}:{settings.port}")
    yield
    logger.info("Shutting down makefeed-integrations service...")


def setup_otel() -> None:
    """Setup OpenTelemetry if enabled."""
    if not settings.otel_enabled:
        logger.info("OpenTelemetry disabled")
        return

    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
            OTLPSpanExporter,
        )
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor

        resource = Resource.create(
            {
                "service.name": settings.otel_service_name,
                "deployment.environment": settings.otel_deployment_environment,
            }
        )

        tracer_provider = TracerProvider(resource=resource)
        span_exporter = OTLPSpanExporter(
            endpoint=settings.otel_exporter_otlp_endpoint,
            insecure=True,
        )
        tracer_provider.add_span_processor(BatchSpanProcessor(span_exporter))
        trace.set_tracer_provider(tracer_provider)

        logger.info(
            f"OpenTelemetry initialized: {settings.otel_service_name} -> "
            f"{settings.otel_exporter_otlp_endpoint}"
        )
    except ImportError as e:
        logger.warning(f"OpenTelemetry packages not available: {e}")
    except Exception as e:
        logger.error(f"Failed to setup OpenTelemetry: {e}")


def create_app() -> Litestar:
    """Create and configure the Litestar application."""
    return Litestar(
        route_handlers=[
            AppStoreWebhookController,
            GlitchTipWebhookController,
            HealthController,
            SentryWebhookController,
        ],
        dependencies={
            "appstore_webhook_service": Provide(
                provide_appstore_webhook_service, sync_to_thread=False
            ),
            "glitchtip_webhook_service": Provide(
                provide_glitchtip_webhook_service, sync_to_thread=False
            ),
            "sentry_webhook_service": Provide(
                provide_sentry_webhook_service, sync_to_thread=False
            ),
        },
        lifespan=[lifespan],
        debug=settings.debug,
    )


app = create_app()


def main() -> None:
    """Run the application with uvicorn."""
    uvicorn.run(
        "makefeed_integrations.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )


def run() -> None:
    """Sync entry point for console script."""
    main()


if __name__ == "__main__":
    main()
