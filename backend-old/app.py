"""FastAPI application factory."""

from __future__ import annotations

import logging
from typing import Callable
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.middleware.cors import CORSMiddleware

from . import __version__
from .core import BackendException, configure_logging, get_settings
from .routers import build_api_router

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging()

    app = FastAPI(
        title="Apex Auto Visualization Backend",
        version=__version__,
        openapi_url="/api/v1/openapi.json",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"] + ["x-correlation-id"],
    )

    @app.middleware("http")
    async def add_correlation_id(request: Request, call_next: Callable):
        correlation_id = request.headers.get("x-correlation-id") or str(uuid4())
        request.state.correlation_id = correlation_id

        response = await call_next(request)
        response.headers["x-correlation-id"] = correlation_id
        return response

    @app.exception_handler(BackendException)
    async def backend_exception_handler(request: Request, exc: BackendException):
        correlation_id = getattr(request.state, "correlation_id", str(uuid4()))
        logger.error(
            "backend.error",
            extra={
                "error": exc.error_code,
                "error_message": str(exc),
                "correlation_id": correlation_id,
                "details": exc.details,
            },
        )
        http_exc = exc.to_http(correlation_id=correlation_id)
        return JSONResponse(status_code=http_exc.status_code, content=http_exc.detail)

    api_router = build_api_router()
    app.include_router(api_router)

    @app.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {"service": app.title, "version": __version__}

    return app


app = create_app()


__all__ = ["create_app", "app"]
