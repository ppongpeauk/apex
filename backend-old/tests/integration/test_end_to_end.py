"""Integration tests for the full API workflow."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from backend.app import create_app
from backend.models import VisualizationDecision


FIXTURE_DIR = Path(__file__).resolve().parent.parent / "data"


def load_schema() -> dict[str, Any]:
    schema_path = Path(__file__).resolve().parents[2] / "schema_0.json"
    with schema_path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture
def client(tmp_path):
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    sample_csv = FIXTURE_DIR / "sample_sales.csv"
    target_csv = data_dir / "sample_sales.csv"
    target_csv.write_bytes(sample_csv.read_bytes())

    def _mock_validate(self, path):  # noqa: ARG001 unused path
        return target_csv

    def _mock_validate_data_path(path_str):  # noqa: ARG001 unused path_str
        return target_csv

    def _mock_validate_executor(path_str):  # noqa: ARG001 unused path_str
        return target_csv

    with patch(
        "backend.services.profiler.DataProfiler._validate_path", new=_mock_validate
    ), patch(
        "backend.utils.files.validate_data_path", new=_mock_validate_data_path
    ), patch(
        "backend.services.executor.validate_data_path", new=_mock_validate_executor
    ):
        app = create_app()
        with TestClient(app) as test_client:
            yield test_client


def mock_decision_payload() -> dict[str, Any]:
    return {
        "chart": {
            "type": "bar",
            "score": 0.9,
            "alternates": [{"type": "line", "score": 0.8, "why": "Trend over time"}],
        },
        "fields": [
            {"name": "order_date", "role": "time", "type": "temporal"},
            {
                "name": "sales",
                "role": "measure",
                "type": "quantitative",
                "aggregate": "sum",
            },
        ],
        "transform": {
            "aggregate": [
                {
                    "groupby": ["order_date"],
                    "measures": [{"field": "sales", "op": "sum", "as": "sales_sum"}],
                }
            ]
        },
        "encoding": {
            "x": {"field": "order_date", "type": "temporal"},
            "y": {
                "field": "sales",
                "aggregate": "sum",
                "type": "quantitative",
            },
        },
        "justification": "Bar chart compares sales by date.",
    }


def _mock_decide_response(*args, **kwargs) -> VisualizationDecision:
    payload = mock_decision_payload()
    return VisualizationDecision.model_validate(payload)


def test_end_to_end_workflow(client):
    ingest_payload = {
        "path": "/tmp/sample_sales.csv",
        "sample_rows": 10,
    }

    ingest_response = client.post("/api/v1/ingest", json=ingest_payload)
    assert ingest_response.status_code == 200
    ingest_data = ingest_response.json()
    assert "profile" in ingest_data
    assert any(col["name"] == "sales" for col in ingest_data["columns_meta"])

    decide_payload = {
        "profile": ingest_data["profile"],
        "sample": ingest_data["sample"],
        "columns": [
            {"name": "order_date", "role": "time", "type": "temporal"},
            {
                "name": "sales",
                "role": "measure",
                "type": "quantitative",
                "aggregate": "sum",
            },
        ],
        "prefer_model": "gpt-5-nano",
        "must_include_alternate": True,
    }

    decide_response = client.post("/api/v1/decide", json=decide_payload)
    assert decide_response.status_code == 200
    decision = decide_response.json()["decision"]
    assert decision["chart"]["type"] in {"bar", "column", "line", "area"}

    render_payload = {
        "path": ingest_payload["path"],
        "decision": decision,
        "filters": [{"field": "sales", "op": "gt", "value": 90}],
        "limit_rows": 100,
    }

    render_response = client.post("/api/v1/render", json=render_payload)
    assert render_response.status_code == 200
    render_data = render_response.json()
    assert "vega_lite" in render_data
    assert render_data["meta"]["applied_filters"] == 1
    assert render_data["data"], "Expected data rows in render response"
