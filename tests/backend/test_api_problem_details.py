from __future__ import annotations

import re

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


def test_not_found_uses_canonical_problem_details_media_type() -> None:
    response = TestClient(create_app(ApiSettings(environment="test"))).get(
        "/does-not-exist",
        headers={"X-Request-ID": "request:not-found"},
    )

    assert response.status_code == 404
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.headers["X-Request-ID"] == "request:not-found"
    assert response.json() == {
        "type": "https://interstellar.dev/problems/not-found",
        "title": "Not Found",
        "status": 404,
        "code": "NOT_FOUND",
        "detail": "Not Found",
        "instance": "/does-not-exist",
        "request_id": "request:not-found",
        "retryable": False,
    }


def test_invalid_request_id_is_replaced() -> None:
    response = TestClient(create_app(ApiSettings(environment="test"))).get(
        "/health/live",
        headers={"X-Request-ID": "not valid because spaces"},
    )

    assert response.status_code == 200
    assert re.fullmatch(r"req-[a-f0-9]{32}", response.headers["X-Request-ID"])
