"""Application entry point for the kinsync-api FastAPI service.

Run locally with:
    uvicorn main:app --reload

In production the app is served by uvicorn under a systemd service, fronted
by Caddy for TLS termination (see specs/deployment.md).
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from internal.config import get_settings
from internal.database import create_engine
from internal.health import router as health_router
from internal.logging_config import configure_logging


@asynccontextmanager
async def lifespan(fastapi_app: FastAPI) -> AsyncIterator[None]:
    """Initialize and dispose of shared resources for the app's lifetime."""
    settings = get_settings()
    configure_logging(settings.log_level)
    fastapi_app.state.db_engine = create_engine(settings)
    yield
    await fastapi_app.state.db_engine.dispose()


def create_app() -> FastAPI:
    """Factory that builds the configured FastAPI application."""
    fastapi_app = FastAPI(title='KinSync API', lifespan=lifespan)
    fastapi_app.include_router(health_router)
    return fastapi_app


app = create_app()
