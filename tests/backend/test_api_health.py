from __future__ import annotations

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


def test_health_and_status_are_available_without_external_services() -> None:
    app = create_app(ApiSettings(environment="test", build_commit="test-commit"))
    client = TestClient(app)

    live = client.get("/health/live")
    assert live.status_code == 200
    assert live.json() == {
        "status": "alive",
        "service": "interstellar-api",
        "version": "0.1.0",
    }

    ready = client.get("/health/ready")
    assert ready.status_code == 200
    assert ready.json()["status"] == "ready"
    assert ready.json()["probes"]["process"]["ready"] is True

    status = client.get("/api/v1/status", headers={"X-Request-ID": "test-request-1"})
    assert status.status_code == 200
    assert status.headers["X-Request-ID"] == "test-request-1"
    body = status.json()
    assert body["status"] == "foundation"
    assert body["build_commit"] == "test-commit"
    assert body["capabilities"]["astrology_calculation"]["state"] == "not_implemented"


def test_readiness_reports_503_when_startup_gate_is_closed() -> None:
    app = create_app(ApiSettings(environment="test", ready_on_startup=False))
    response = TestClient(app).get("/health/ready")

    assert response.status_code == 503
    assert response.json()["status"] == "not_ready"
    assert response.json()["probes"]["process"] == {
        "ready": False,
        "detail": "startup gate disabled",
    }
