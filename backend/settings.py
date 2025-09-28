"""Environment-driven configuration values for Sprint 1 backend."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


# Load .env if present in project root.
load_dotenv(Path(__file__).resolve().parent / ".env")

MAX_FILE_MB = int(os.getenv("MAX_FILE_MB", "10"))
MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024

DEFAULT_SAMPLE_ROWS = int(os.getenv("SAMPLE_ROWS", "200"))

ALLOWED_CHART_TYPES = ("bar", "line", "histogram")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
