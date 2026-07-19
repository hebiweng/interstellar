from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app

FIXTURES = Path(__file__).parents[1] / "data" / "fixtures"


def _client() -> TestClient:
    settings = ApiSettings(
        environment="test",
        geonames_path=str(FIXTURES / "geonames.tsv"),
        geonames_dataset_version="fixture-geonames-v1",
        timezone_boundaries_path=str(FIXTURES / "timezone-boundaries.geojson"),
        timezone_boundaries_dataset_version="fixture-tz-v1",
    )
    return TestClient(create_app(settings))


def test_location_search_returns_coordinates_and_resolved_timezone() -> None:
    response = _client().get(
        "/api/v1/locations/search",
        params={"q": "Beijing", "country_code": "CN"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["items"][0]["id"].startswith("geonames:")
    assert payload["items"][0]["location"]["timezone_id"] == "Asia/Shanghai"
    assert payload["items"][0]["timezone_status"] == "resolved"
    assert payload["items"][0]["timezone_candidates"][0]["boundary_match"] is True
    assert payload["datasets"][0] == {
        "provider": "GeoNames",
        "version": "fixture-geonames-v1",
        "license": "CC-BY-4.0",
    }


def test_location_search_exposes_ambiguity_without_auto_selection() -> None:
    response = _client().get(
        "/api/v1/locations/search", params={"q": "Boundaryville"}
    )
    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["timezone_status"] == "ambiguous"
    assert item["location"]["timezone_id"] is None
    assert {candidate["timezone_id"] for candidate in item["timezone_candidates"]} == {
        "Etc/GMT+1",
        "Etc/GMT-1",
    }


def test_location_search_returns_problem_when_datasets_are_not_mounted() -> None:
    client = TestClient(create_app(ApiSettings(environment="test")))
    response = client.get("/api/v1/locations/search", params={"q": "Beijing"})
    assert response.status_code == 503
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["title"] == "Location dataset unavailable"
