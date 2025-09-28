"""Composer that maps decisions to Vega-Lite specifications."""

from __future__ import annotations

from typing import Any

from ..models import VisualizationDecision


class Composer:
    def compose(
        self, decision: VisualizationDecision, data: list[dict[str, Any]]
    ) -> dict[str, Any]:
        mark = decision.chart.type.value
        spec = {
            "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
            "data": {"values": data},
            "mark": self._map_mark(mark),
            "encoding": self._build_encoding(decision),
            "config": {"axis": {"labelAngle": 0}},
        }
        return spec

    def _map_mark(self, mark_type: str) -> Any:
        mapping = {
            "stacked_bar": {"type": "bar", "stack": "normal"},
            "diverging_stacked_bar": {"type": "bar", "stack": "normalize"},
        }
        return mapping.get(mark_type, mark_type)

    def _build_encoding(self, decision: VisualizationDecision) -> dict[str, Any]:
        encoding: dict[str, Any] = {}

        if decision.encoding.x:
            encoding["x"] = self._encode_channel(decision.encoding.x)
        if decision.encoding.y:
            encoding["y"] = self._encode_channel(decision.encoding.y)
        if decision.encoding.color:
            encoding["color"] = self._encode_channel(decision.encoding.color)
        if decision.encoding.size:
            encoding["size"] = self._encode_channel(decision.encoding.size)
        if decision.encoding.shape:
            encoding["shape"] = self._encode_channel(decision.encoding.shape)

        return encoding

    def _encode_channel(self, channel) -> dict[str, Any]:
        spec: dict[str, Any] = {}
        if channel.field:
            spec["field"] = channel.field
        if channel.type:
            spec["type"] = channel.type.value
        if channel.aggregate:
            spec["aggregate"] = channel.aggregate.value
        if channel.time_unit:
            spec["timeUnit"] = channel.time_unit.value
        if channel.bin:
            spec["bin"] = (
                True
                if isinstance(channel.bin, bool)
                else channel.bin.dict(exclude_none=True)
            )
        return spec


__all__ = ["Composer"]
