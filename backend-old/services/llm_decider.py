"""LLM decision service integrating with the OpenAI Python client."""

from __future__ import annotations

import json
import logging
import textwrap
from pathlib import Path
from typing import Any

from openai import AsyncOpenAI

from ..core import ModelDecisionFailedError, SchemaValidationFailedError, get_settings
from ..models import VisualizationDecision

logger = logging.getLogger(__name__)


class LLMDecider:
    def __init__(
        self,
        settings=None,
        schema_path: Path | None = None,
        client: AsyncOpenAI | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.schema_path = schema_path
        self._schema_cache: dict[str, Any] | None = None
        self.client = client or AsyncOpenAI(
            api_key=self.settings.openai_api_key,
            max_retries=0,
        )

    @property
    def schema(self) -> dict[str, Any]:
        if self._schema_cache is None:
            if not self.schema_path:
                raise RuntimeError("Schema path not configured")
            with self.schema_path.open("r", encoding="utf-8") as f:
                self._schema_cache = json.load(f)
        return self._schema_cache

    async def decide(
        self, payload: dict[str, Any], *, prefer_model: str | None = None
    ) -> VisualizationDecision:
        model_name = prefer_model or self.settings.openai_model_fast
        try:
            response = await self._call_openai(model_name, payload)
        except ModelDecisionFailedError as err:
            fallback = self._fallback_decision(payload, reason=str(err))
            if fallback is not None:
                logger.warning(
                    "llm.decide.fallback",
                    extra={"reason": str(err)},
                )
                return fallback
            raise

        try:
            decision = VisualizationDecision.model_validate(response)
        except Exception as exc:  # noqa: BLE001
            logger.exception("llm.decide.validation_failed")
            raise SchemaValidationFailedError(
                "Invalid decision", details=str(exc)
            ) from exc

        return decision

    async def _call_openai(self, model_name: str, payload: dict[str, Any]) -> Any:
        if not self.settings.openai_api_key:
            raise ModelDecisionFailedError("OpenAI API key not configured")

        try:
            response = await self.client.responses.create(
                model=model_name,
                input=self._build_messages(payload),
            )
        except Exception as exc:  # noqa: BLE001
            raise ModelDecisionFailedError("OpenAI request failed", details=str(exc))

        try:
            raw_output = getattr(response, "output_text", None)
            if not raw_output and getattr(response, "output", None):
                segments = []
                for block in response.output:  # type: ignore[assignment]
                    if hasattr(block, "content"):
                        for item in block.content:
                            if getattr(item, "type", None) == "output_text":
                                segments.append(item.text)
                raw_output = "".join(segments)
            if not raw_output:
                raise ValueError("Empty response from OpenAI")
            return json.loads(raw_output)
        except Exception as exc:  # noqa: BLE001
            raise ModelDecisionFailedError(
                "Failed to parse OpenAI response",
                details=getattr(response, "output", None),
            ) from exc

    def _build_messages(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        profile = payload.get("profile") or {}
        columns = payload.get("columns") or []
        sample = payload.get("sample") or []
        sample_preview = sample[:5]

        user_prompt = textwrap.dedent(
            f"""
            You are assisting with automatic visualization selection. Return a JSON object
            that conforms to the provided JSON schema. Do not include any text outside of
            the JSON payload.

            JSON Schema (draft 2020-12):
            {json.dumps(self.schema, indent=2)}

            Dataset profile:
            {json.dumps(profile, indent=2)}

            Columns metadata:
            {json.dumps(columns, indent=2)}

            Sample rows (up to 5 shown):
            {json.dumps(sample_preview, indent=2)}

            Requirements:
            - Choose a primary chart type from the allowed enum.
            - Include alternates only when appropriate.
            - Limit transforms to aggregate, filter, bin, and time_unit as defined in schema.
            - Use clear field roles and ensure referenced fields exist in the columns list.
            - Justification should be concise.
            """
        ).strip()

        return [
            {
                "role": "system",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "You are a visualization planning assistant. "
                            "Always respond with strict JSON matching the schema."
                        ),
                    }
                ],
            },
            {
                "role": "user",
                "content": [{"type": "input_text", "text": user_prompt}],
            },
        ]

    def _fallback_decision(
        self, payload: dict[str, Any], *, reason: str
    ) -> VisualizationDecision | None:
        columns = payload.get("columns") or []

        def cols_of_type(col_type: str) -> list[dict[str, Any]]:
            return [
                col for col in columns if (col.get("type") or "").lower() == col_type
            ]

        quantitative = cols_of_type("quantitative")
        temporal = cols_of_type("temporal")
        nominal = cols_of_type("nominal")

        decision_payload: dict[str, Any] | None = None

        if temporal and quantitative:
            t_field = temporal[0]["name"]
            q_field = quantitative[0]["name"]
            decision_payload = {
                "chart": {"type": "line", "score": 0.3},
                "fields": [
                    {"name": t_field, "role": "time", "type": "temporal"},
                    {
                        "name": q_field,
                        "role": "measure",
                        "type": "quantitative",
                        "aggregate": "sum",
                    },
                ],
                "encoding": {
                    "x": {"field": t_field, "type": "temporal"},
                    "y": {
                        "field": q_field,
                        "aggregate": "sum",
                        "type": "quantitative",
                    },
                },
                "justification": (
                    "LLM unavailable; fallback line chart showing quantitative trend over time."
                ),
            }
        elif nominal and quantitative:
            n_field = nominal[0]["name"]
            q_field = quantitative[0]["name"]
            decision_payload = {
                "chart": {"type": "bar", "score": 0.3},
                "fields": [
                    {"name": n_field, "role": "dimension", "type": "nominal"},
                    {
                        "name": q_field,
                        "role": "measure",
                        "type": "quantitative",
                        "aggregate": "sum",
                    },
                ],
                "encoding": {
                    "x": {"field": n_field, "type": "nominal"},
                    "y": {
                        "field": q_field,
                        "aggregate": "sum",
                        "type": "quantitative",
                    },
                },
                "justification": (
                    "LLM unavailable; fallback bar chart comparing quantitative values across categories."
                ),
            }
        elif len(quantitative) >= 2:
            x_field = quantitative[0]["name"]
            y_field = quantitative[1]["name"]
            decision_payload = {
                "chart": {"type": "scatter", "score": 0.3},
                "fields": [
                    {"name": x_field, "role": "measure", "type": "quantitative"},
                    {"name": y_field, "role": "measure", "type": "quantitative"},
                ],
                "encoding": {
                    "x": {"field": x_field, "type": "quantitative"},
                    "y": {"field": y_field, "type": "quantitative"},
                },
                "justification": (
                    "LLM unavailable; fallback scatter plot to observe relationship between two measures."
                ),
            }
        elif len(quantitative) == 1:
            q_field = quantitative[0]["name"]
            decision_payload = {
                "chart": {"type": "histogram", "score": 0.3},
                "fields": [
                    {"name": q_field, "role": "measure", "type": "quantitative"},
                ],
                "encoding": {
                    "x": {"field": q_field, "type": "quantitative", "bin": True},
                    "y": {
                        "field": q_field,
                        "type": "quantitative",
                        "aggregate": "count",
                    },
                },
                "justification": (
                    "LLM unavailable; fallback histogram to show distribution of the measure."
                ),
            }

        if decision_payload is None:
            return None

        if payload.get("profile"):
            decision_payload["profile"] = payload["profile"]

        decision_payload["assumptions"] = [
            "Heuristic fallback applied because model decision failed",
            f"Reason: {reason}",
        ]

        return VisualizationDecision.model_validate(decision_payload)


__all__ = ["LLMDecider"]
