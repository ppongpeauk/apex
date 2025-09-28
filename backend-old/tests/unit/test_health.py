"""Unit tests for health endpoint."""

from fastapi.testclient import TestClient

from backend.app import create_app


def test_healthz():
    client = TestClient(create_app())
    response = client.get("/api/v1/healthz")
    assert response.status_code == 200
    assert response.json() == {"ok": True}
