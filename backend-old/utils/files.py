"""Utilities for working with file paths used by services."""

from __future__ import annotations

from pathlib import Path

from ..core import InvalidRequestError, get_settings


def validate_data_path(path_str: str) -> Path:
    settings = get_settings()
    path = Path(path_str).expanduser()

    if not path.exists():
        raise InvalidRequestError(f"Path not found: {path}")
    if path.is_dir():
        raise InvalidRequestError("Expected a file path, received directory")

    allowed_roots = settings.allowed_data_roots
    if allowed_roots:
        resolved_path = path.resolve()
        for root in allowed_roots:
            if resolved_path.is_relative_to(Path(root).resolve()):
                break
        else:
            raise InvalidRequestError("Path not allowed by server configuration")

    return path


__all__ = ["validate_data_path"]
