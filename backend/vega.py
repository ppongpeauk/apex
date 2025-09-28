"""Translate chart decisions to Vega-Lite specifications."""

from __future__ import annotations

from typing import Any, Dict


def _encode_channel(channel: Dict[str, Any]) -> Dict[str, Any]:
    encoding = {"field": channel["field"], "type": channel["type"]}
    if channel.get("aggregate"):
        encoding["aggregate"] = channel["aggregate"]
    if channel.get("time_unit"):
        encoding["timeUnit"] = channel["time_unit"]
    if channel.get("bin") is True:
        encoding["bin"] = True
    return encoding


def decision_to_vegalite(decision: Dict[str, Any]) -> Dict[str, Any]:
    chart_type = decision["chart"]["type"]
    plot = decision["plot"]

    spec: Dict[str, Any] = {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "title": decision["title"],
        "data": {"name": "table"},
        "encoding": {},
    }

    if chart_type == "bar":
        spec["mark"] = "bar"
        spec["encoding"]["x"] = _encode_channel(plot["x"])
        spec["encoding"]["y"] = _encode_channel(plot["y"])
        if plot.get("series"):
            spec["encoding"]["color"] = _encode_channel(plot["series"])

    elif chart_type == "line":
        spec["mark"] = "line"
        spec["encoding"]["x"] = _encode_channel(plot["x"])
        spec["encoding"]["y"] = _encode_channel(plot["y"])
        spec["encoding"]["y"]["scale"] = {"zero": False}
        if plot.get("series"):
            spec["encoding"]["color"] = _encode_channel(plot["series"])

    elif chart_type == "histogram":
        spec["mark"] = "bar"
        x_channel = _encode_channel(plot["x"])
        if "bin" not in x_channel:
            x_channel["bin"] = True
        spec["encoding"]["x"] = x_channel
        spec["encoding"]["y"] = {"aggregate": "count", "type": "quantitative"}

    else:  # pragma: no cover - restricted by prompt and validation
        spec["mark"] = "bar"

    return spec
