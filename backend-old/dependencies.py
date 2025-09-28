"""FastAPI dependency providers for service instances."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from .core import get_settings
from .services import Composer, DataProfiler, LLMDecider, TransformExecutor


@lru_cache(maxsize=1)
def _get_schema_path() -> Path:
    return Path(__file__).resolve().parent / "schema_0.json"


@lru_cache(maxsize=1)
def get_profiler() -> DataProfiler:
    return DataProfiler(settings=get_settings())


@lru_cache(maxsize=1)
def get_decider() -> LLMDecider:
    return LLMDecider(settings=get_settings(), schema_path=_get_schema_path())


@lru_cache(maxsize=1)
def get_executor() -> TransformExecutor:
    return TransformExecutor(settings=get_settings())


@lru_cache(maxsize=1)
def get_composer() -> Composer:
    return Composer()


__all__ = [
    "get_profiler",
    "get_decider",
    "get_executor",
    "get_composer",
]
