"""Wrapper around the OpenAI API for Sprint 1 backend."""

from __future__ import annotations

import json
from typing import Any, Dict

from openai import AsyncOpenAI

from settings import OPENAI_API_KEY


# Configuration for LLM service
# Set these to your preferred values:
LLM_BASE_URL = "http://localhost:11434/v1"  # For Ollama local API
LLM_API_KEY = "ollama"  # Dummy key for local Ollama (not actually used)
LLM_MODEL = "gemma3:4b"  # Model to use

# Alternative configurations:
# For OpenAI:
# LLM_BASE_URL = "https://api.openai.com/v1"
# LLM_API_KEY = os.getenv("OPENAI_API_KEY")  # Use the real key from .env
# LLM_MODEL = "gpt-5-nano"

SYSTEM_PROMPT = """You output a single JSON object that matches this schema:
ChartDecision = {
  chart: { type: "bar"|"line"|"histogram", score: number (0..1) },
  title: string,
  x_label: string,
  y_label: string,
  fields_used: string[],
  plot: {
    x: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal", time_unit?: string, bin?: boolean, aggregate?: string },
    y: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal", time_unit?: string, bin?: boolean, aggregate?: string },
    series?: { field: string, type: "nominal"|"ordinal"|"quantitative"|"temporal" }
  },
  justification: string
}
Rules:
- Choose exactly one chart type from: bar, line, histogram.
- Prefer bar for nominal vs numeric comparisons with limited categories.
- Prefer line when x is temporal and y is numeric; set time_unit if needed.
- Prefer histogram for distributions of a single numeric field (set bin=true on the binned channel).
- Return ONLY JSON. No markdown, no commentary.
"""


_client: AsyncOpenAI | None = None


def _get_client() -> AsyncOpenAI:
    global _client
    if _client is None:
        _client = AsyncOpenAI(
            api_key=LLM_API_KEY,
            base_url=LLM_BASE_URL,
        )
    return _client


async def call_llm(*, model: str, prompt: Dict[str, Any]) -> Dict[str, Any]:
    """Call the OpenAI API and return structured JSON for chart decision."""

    client = _get_client()
    response = await client.chat.completions.create(
        model=LLM_MODEL,  # Use configured model instead of passed parameter
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(prompt)},
        ],
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content
    print(content)
    if not content:
        raise RuntimeError("LLM returned empty content")

    return json.loads(content)
