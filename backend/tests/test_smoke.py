"""Integration smoke tests that exercise the live OpenAI call."""

from __future__ import annotations

import os
import pathlib

import pytest
from fastapi.testclient import TestClient

from app import app as fastapi_app


if not os.getenv("OPENAI_API_KEY"):
    pytest.skip(
        "OPENAI_API_KEY missing; skipping integration tests", allow_module_level=True
    )


client = TestClient(fastapi_app)
SAMPLES = pathlib.Path(__file__).parent / "samples"


def _upload(name: str):
    path = SAMPLES / name
    with path.open("rb") as file_handle:
        # Determine content type based on file extension
        if name.endswith(".csv"):
            content_type = "text/csv"
        elif name.endswith(".tsv"):
            content_type = "text/tab-separated-values"
        elif name.endswith(".json"):
            content_type = "application/json"
        else:
            content_type = "application/octet-stream"

        return client.post(
            "/analyze", files={"file": (name, file_handle, content_type)}
        )


def test_bar_chart_returns_bar():
    response = _upload("cats_nums.csv")
    assert response.status_code == 200
    body = response.json()
    assert body["decision"]["chart"]["type"] == "bar"


def test_temporal_data_returns_valid_chart():
    response = _upload("temporal_numeric.csv")
    assert response.status_code == 200
    body = response.json()
    # Just check that it returns a valid chart type, not a specific one
    assert body["decision"]["chart"]["type"] in ["bar", "line", "histogram"]
    assert "vega_lite" in body
    assert body["vega_lite"]["mark"] in ["bar", "line"]


def test_single_numeric_returns_valid_chart():
    response = _upload("single_numeric.csv")
    assert response.status_code == 200
    body = response.json()
    # Just check that it returns a valid chart type, not a specific one
    assert body["decision"]["chart"]["type"] in ["bar", "line", "histogram"]
    assert "vega_lite" in body
    assert body["vega_lite"]["mark"] in ["bar", "line"]
