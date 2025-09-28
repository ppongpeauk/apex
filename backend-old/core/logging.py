"""Structured logging configuration."""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Any

from .config import get_settings


def _json_formatter(record: logging.LogRecord) -> str:
    payload: dict[str, Any] = {
        "level": record.levelname,
        "message": record.getMessage(),
        "logger": record.name,
        "time": getattr(record, "asctime", None),
    }

    extra_keys = set(record.__dict__.keys()) - {
        "name",
        "msg",
        "args",
        "levelname",
        "levelno",
        "pathname",
        "filename",
        "module",
        "exc_info",
        "exc_text",
        "stack_info",
        "lineno",
        "funcName",
        "created",
        "msecs",
        "relativeCreated",
        "thread",
        "threadName",
        "processName",
        "process",
    }

    for key in extra_keys:
        payload[key] = record.__dict__[key]

    return json.dumps(payload, default=str)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        record.message = record.getMessage()
        return _json_formatter(record)


def configure_logging() -> None:
    settings = get_settings()
    logging.basicConfig(level=settings.log_level)

    if settings.log_json:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())

        root_logger = logging.getLogger()
        root_logger.handlers.clear()
        root_logger.addHandler(handler)
        root_logger.setLevel(settings.log_level)

        os.environ["UVICORN_ACCESS_LOG"] = "false"


__all__ = ["configure_logging", "JsonFormatter"]
