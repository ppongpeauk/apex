"""Render request and response models."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from .decision import VisualizationDecision
from .filters import FilterSpecRequest


class RenderRequest(BaseModel):
    path: str
    decision: VisualizationDecision
    filters: list[FilterSpecRequest] | None = None
    limit_rows: int | None = Field(default=None, ge=1)


class RenderResponse(BaseModel):
    vega_lite: dict[str, Any]
    data: list[dict[str, Any]]
    meta: dict[str, Any]


__all__ = ["RenderRequest", "RenderResponse"]
