from __future__ import annotations

from pathlib import Path

import yaml
from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


def _client() -> TestClient:
    return TestClient(create_app(ApiSettings(environment="test")))


def test_dataset_catalog_distinguishes_runtime_and_adapter_pending_sources() -> None:
    response = _client().get("/api/v1/datasets", params={"page[limit]": 100})
    assert response.status_code == 200
    items = {item["id"]: item for item in response.json()["items"]}

    assert items["swiss_ephemeris"]["status"] == "active"
    assert (
        items["swiss_ephemeris"]["metadata"]["capability_state"]
        == "primary_calculation_active"
    )
    assert items["jpl_spice"]["status"] == "active"
    assert (
        items["jpl_spice"]["metadata"]["capability_state"]
        == "local_validation_source_adapter_pending"
    )
    assert items["iers"]["metadata"]["local_ready"] is True
    assert items["natural_earth"]["status"] == "active"
    assert (
        items["natural_earth"]["metadata"]["capability_state"]
        == "local_map_source_ready_renderer_pending"
    )
    assert items["gaia_dr3"]["status"] == "discovered"
    assert items["gaia_dr3"]["metadata"]["local_ready"] is False


def test_every_required_capability_has_a_local_required_data_source() -> None:
    response = _client().get("/api/v1/datasets", params={"page[limit]": 100})
    active_ids = {
        item["id"]
        for item in response.json()["items"]
        if item["status"] == "active" and item["metadata"]["local_ready"] is True
    }
    capabilities_path = Path(__file__).resolve().parents[2] / "docs" / "capabilities.yaml"
    document = yaml.safe_load(capabilities_path.read_text(encoding="utf-8"))
    missing: dict[str, list[str]] = {}
    for capability in document["capabilities"]:
        if capability.get("v1_required") is not True:
            continue
        unavailable = [
            dataset_id
            for dataset_id in capability.get("data_sources", [])
            if dataset_id not in active_ids
        ]
        if unavailable:
            missing[capability["id"]] = unavailable
    assert missing == {}


def test_dataset_version_endpoint_exposes_provenance_and_artifacts() -> None:
    response = _client().get(
        "/api/v1/datasets/jpl_spice/versions/de442-validation-kernel-set-2025-02-06"
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["source_uri"].startswith("https://naif.jpl.nasa.gov/")
    assert payload["metadata"]["crawler"] is False
    assert payload["metadata"]["artifacts"][0]["exists"] is True
    assert payload["metadata"]["artifacts"][0]["size_matches"] is True


def test_unknown_dataset_version_uses_problem_json() -> None:
    response = _client().get("/api/v1/datasets/not-real/versions/nope")
    assert response.status_code == 404
    assert response.headers["content-type"].startswith("application/problem+json")
