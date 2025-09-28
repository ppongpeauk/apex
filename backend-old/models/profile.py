"""Dataset profiling models."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from .decision import SemanticType


class ColumnProfile(BaseModel):
    name: str
    inferred_type: SemanticType
    unique: int | None = Field(default=None, ge=0)
    missing: int | None = Field(default=None, ge=0)
    outliers: int | None = Field(default=None, ge=0)
    sample_values: list[Any] | None = None


class DatasetProfileResponse(BaseModel):
    row_count: int | None = Field(default=None, ge=0)
    columns: list[ColumnProfile]
    issues: list[str] | None = None
    time_granularity: dict[str, str] | None = None


class IngestResponse(BaseModel):
    profile: DatasetProfileResponse
    sample: list[dict[str, Any]]
    columns_meta: list[dict[str, Any]]
    suggestions: list[str] | None = None


class IngestRequest(BaseModel):
    path: str
    sample_rows: int | None = Field(default=None, ge=1)
    type_hints: dict[str, str] | None = None


__all__ = [
    "ColumnProfile",
    "DatasetProfileResponse",
    "IngestRequest",
    "IngestResponse",
]
