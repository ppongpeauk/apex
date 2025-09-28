"""Filter request/response models."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from .decision import FilterSpec


class FilterSpecRequest(FilterSpec):
    pass


class FilterRequest(BaseModel):
    path: str
    filters: list[FilterSpecRequest] | None = None
    limit_rows: int | None = Field(default=None, ge=1)


class FilteredDataResponse(BaseModel):
    data: list[dict[str, Any]]
    meta: dict[str, Any]


__all__ = ["FilterRequest", "FilterSpecRequest", "FilteredDataResponse"]
