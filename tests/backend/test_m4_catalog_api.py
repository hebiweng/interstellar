from __future__ import annotations

import re

from fastapi import FastAPI
from fastapi.testclient import TestClient
from interstellar_core.analysis.registries import load_analysis_registry

from interstellar_api.errors import install_problem_handlers
from interstellar_api.routers.m4_catalogs import router


def _client(*, with_registry: bool = True) -> TestClient:
    app = FastAPI()
    install_problem_handlers(app)
    if with_registry:
        app.state.analysis_registry = load_analysis_registry()
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


def _assert_catalog_item(item: dict[str, object]) -> None:
    assert set(item) == {"id", "version", "name", "maturity", "content_hash", "payload"}
    assert item["maturity"] in {"stable", "beta", "experimental"}
    assert re.fullmatch(r"sha256:[0-9a-f]{64}", str(item["content_hash"]))
    assert isinstance(item["payload"], dict)


def test_all_catalog_lists_return_canonical_pages() -> None:
    client = _client()

    expected_counts = {
        "/api/v1/entry-points": 6,
        "/api/v1/analysis-models": 12,
        "/api/v1/topic-models": 24,
        "/api/v1/analysis-intents": 35,
    }
    for path, expected_count in expected_counts.items():
        response = client.get(path, params={"page[limit]": 100})
        assert response.status_code == 200, response.text
        document = response.json()
        assert set(document) == {"items", "page"}
        assert len(document["items"]) == expected_count
        assert document["page"] == {"next_cursor": None, "has_more": False}
        for item in document["items"]:
            _assert_catalog_item(item)


def test_catalog_hash_and_payload_are_stable_across_requests() -> None:
    client = _client()

    first = client.get("/api/v1/analysis-models/natal.modern.v1").json()
    second = client.get("/api/v1/analysis-models/natal.modern.v1").json()

    assert first == second
    assert first["payload"]["components"] == [
        "natal.standard_chart",
        "natal.patterns_distributions",
    ]


def test_search_and_maturity_filters_are_applied_before_pagination() -> None:
    client = _client()

    search = client.get("/api/v1/topic-models", params={"q": "职业"})
    assert search.status_code == 200
    assert [item["id"] for item in search.json()["items"]] == ["topic.career_vocation.v1"]

    stable = client.get(
        "/api/v1/analysis-models",
        params={"maturity": "stable", "page[limit]": 1},
    )
    assert stable.status_code == 200
    first_page = stable.json()
    assert len(first_page["items"]) == 1
    assert first_page["items"][0]["maturity"] == "stable"
    assert first_page["page"]["has_more"] is True

    second_page = client.get(
        "/api/v1/analysis-models",
        params={
            "maturity": "stable",
            "page[limit]": 100,
            "page[cursor]": first_page["page"]["next_cursor"],
        },
    )
    assert second_page.status_code == 200
    assert all(item["maturity"] == "stable" for item in second_page.json()["items"])
    assert first_page["items"][0]["id"] not in {
        item["id"] for item in second_page.json()["items"]
    }


def test_versioned_catalog_resources_match_registry_versions() -> None:
    client = _client()

    model = client.get("/api/v1/analysis-models/natal.modern.v1/versions/1.0.0")
    topic = client.get("/api/v1/topic-models/personality.modern.v1/versions/1.0.0")
    intent = client.get("/api/v1/analysis-intents/intent.natal_overview/versions/1.0.0")

    for response in (model, topic, intent):
        assert response.status_code == 200, response.text
        _assert_catalog_item(response.json())
        assert response.json()["version"] == "1.0.0"


def test_unknown_resource_and_version_return_problem_details() -> None:
    client = _client()

    responses = [
        client.get("/api/v1/analysis-models/missing.model"),
        client.get("/api/v1/analysis-models/natal.modern.v1/versions/9.9.9"),
        client.get("/api/v1/topic-models/missing.topic/versions/1.0.0"),
        client.get("/api/v1/analysis-intents/missing.intent/versions/1.0.0"),
    ]

    for response in responses:
        assert response.status_code == 404
        assert response.headers["content-type"].startswith("application/problem+json")
        assert response.json()["code"] == "NOT_FOUND"


def test_invalid_cursor_and_missing_registry_return_problem_details() -> None:
    invalid_cursor = _client().get(
        "/api/v1/entry-points", params={"page[cursor]": "not-a-cursor"}
    )
    assert invalid_cursor.status_code == 400
    assert invalid_cursor.json()["code"] == "INVALID_REQUEST"

    unavailable = _client(with_registry=False).get("/api/v1/entry-points")
    assert unavailable.status_code == 500
    assert unavailable.json()["code"] == "INTERNAL_ERROR"
    assert unavailable.json()["retryable"] is True
