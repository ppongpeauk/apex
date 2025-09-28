"""Application configuration using Pydantic settings."""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables."""

    openai_api_key: str | None = Field(default=None, alias="OPENAI_API_KEY")
    openai_model_fast: str = Field(default="gpt-5-mini", alias="OPENAI_MODEL_FAST")
    openai_model_strict: str = Field(default="gpt-5-mini", alias="OPENAI_MODEL_STRICT")

    service_port: int = Field(default=8080, alias="SERVICE_PORT")
    max_file_mb: int = Field(default=50, alias="MAX_FILE_MB")
    max_rows: int = Field(default=500_000, alias="MAX_ROWS")
    llm_sample_rows: int = Field(default=1_000, alias="LLM_SAMPLE_ROWS")
    cache_ttl_sec: int = Field(default=300, alias="CACHE_TTL_SEC")

    log_level: Literal["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"] = Field(
        default="INFO", alias="LOG_LEVEL"
    )
    log_json: bool = Field(default=True, alias="LOG_JSON")

    allowed_data_roots: list[str] | None = Field(
        default=None, alias="ALLOWED_DATA_ROOTS"
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    """Return a cached instance of :class:`Settings`."""

    return Settings()


__all__ = ["Settings", "get_settings"]
