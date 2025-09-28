"""Decision request models."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from .decision import FieldSpec, VisualizationDecision
from .profile import DatasetProfileResponse


class DecideRequest(BaseModel):
    profile: DatasetProfileResponse | None = None
    sample: list[dict[str, Any]] = Field(default_factory=list, max_length=1000)
    columns: list[FieldSpec]
    prefer_model: str | None = None
    must_include_alternate: bool = False


class DecideResponse(BaseModel):
    decision: VisualizationDecision


__all__ = ["DecideRequest", "DecideResponse"]
