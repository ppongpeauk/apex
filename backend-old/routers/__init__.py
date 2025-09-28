"""API routers for the backend service."""

from fastapi import APIRouter

from .decide import router as decide_router
from .health import router as health_router
from .ingest import router as ingest_router
from .render import router as render_router


def build_api_router() -> APIRouter:
    api_router = APIRouter(prefix="/api/v1")
    api_router.include_router(health_router)
    api_router.include_router(ingest_router)
    api_router.include_router(decide_router)
    api_router.include_router(render_router)
    return api_router


__all__ = ["build_api_router"]
