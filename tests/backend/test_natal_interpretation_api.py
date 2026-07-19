from __future__ import annotations

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app
from tests.reporting.test_contextual import snapshot_fixture


def _client_with_snapshot() -> TestClient:
    app = create_app(ApiSettings(environment="test"))
    app.state.workflow_store.put_snapshot(snapshot_fixture())
    return TestClient(app, raise_server_exceptions=False)


def _birth_payload() -> dict:
    return {
        "workspace_id": "workspace-contextual",
        "version": {
            "kind": "person",
            "display_name": "Contextual Integration Subject",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": "2000-01-01T20:00",
                "precision": "minute",
                "timezone_id": "Asia/Shanghai",
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high",
                "source": {"kind": "test_fixture"},
                "warnings": [],
            },
            "location": {
                "name": "Shanghai",
                "country_code": "CN",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "timezone_id": "Asia/Shanghai",
                "source": "test_fixture",
                "warnings": [],
            },
            "attributes": {},
            "source": {"kind": "test_fixture"},
        },
    }


def _calculation_payload(subject_version_id: str) -> dict:
    return {
        "subject": {"subject_version_id": subject_version_id},
        "chart": {"family": "natal", "technique": "natal.standard_chart"},
        "settings": {
            "zodiac": "tropical",
            "house_system": "placidus",
            "center": "geocentric",
            "coordinate_frame": "ecliptic",
            "node_type": "true",
            "aspect_set_id": "official.aspects.major.v1",
            "orb_profile_id": "official.orbs.standard.v1",
            "included_points": [
                "sun",
                "moon",
                "mercury",
                "venus",
                "mars",
                "jupiter",
                "saturn",
                "uranus",
                "neptune",
                "pluto",
                "asc",
                "dsc",
                "mc",
                "ic",
            ],
            "custom_parameters": {},
        },
        "rule_pack_hash": f"sha256:{'a' * 64}",
        "dataset_versions": {},
        "outputs": ["snapshot", "json"],
    }


def test_batch_contextual_api_returns_published_and_unavailable_items() -> None:
    with _client_with_snapshot() as client:
        response = client.post(
            "/api/v1/calculations/snapshot-contextual-1/interpretations/contextual",
            json={
                "items": [
                    {
                        "item_kind": "point_in_sign",
                        "result_path": "/result/points/0",
                    },
                    {
                        "item_kind": "motion",
                        "result_path": "/result/points/0",
                    },
                ]
            },
        )

    assert response.status_code == 200, response.text
    document = response.json()
    assert document["schema_version"] == "1.0.0"
    assert document["generation_mode"] == "deterministic_rule_template"
    assert document["ai_used"] is False
    assert [item["status"] for item in document["interpretations"]] == [
        "published",
        "not_applicable",
    ]


def test_contextual_api_returns_problem_for_invalid_fact_path() -> None:
    with _client_with_snapshot() as client:
        response = client.post(
            "/api/v1/calculations/snapshot-contextual-1/interpretations/contextual",
            json={
                "items": [
                    {
                        "item_kind": "point_intrinsic",
                        "result_path": "/result/points/999",
                    }
                ]
            },
        )

    assert response.status_code == 422
    assert response.json()["code"] == "INVALID_REQUEST"
    assert "items.0.result_path" in response.json()["fields"]


def test_contextual_api_returns_not_found_for_unknown_snapshot() -> None:
    with _client_with_snapshot() as client:
        response = client.post(
            "/api/v1/calculations/missing/interpretations/contextual",
            json={
                "items": [
                    {
                        "item_kind": "point_intrinsic",
                        "result_path": "/result/points/0",
                    }
                ]
            },
        )

    assert response.status_code == 404
    assert response.json()["code"] == "NOT_FOUND"


def test_real_natal_snapshot_supports_all_eight_contextual_item_kinds() -> None:
    app = create_app(ApiSettings(environment="test"))
    with TestClient(app, raise_server_exceptions=False) as client:
        subject = client.post("/api/v1/subjects", json=_birth_payload()).json()
        calculation = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(subject["version"]["id"]),
        )
        assert calculation.status_code == 201, calculation.text
        snapshot = calculation.json()
        response = client.post(
            f"/api/v1/calculations/{snapshot['id']}/interpretations/contextual",
            json={
                "items": [
                    {"item_kind": "point_intrinsic", "result_path": "/result/points/0"},
                    {"item_kind": "point_in_sign", "result_path": "/result/points/0"},
                    {"item_kind": "point_in_house", "result_path": "/result/points/0"},
                    {"item_kind": "motion", "result_path": "/result/points/2"},
                    {"item_kind": "natal_aspect", "result_path": "/result/aspects/0"},
                    {
                        "item_kind": "house_cusp_ruler",
                        "result_path": "/result/houses/0",
                    },
                    {
                        "item_kind": "structure_indicator",
                        "result_path": "/result/structure/angularity/facts/0",
                    },
                    {
                        "item_kind": "classical_condition",
                        "result_path": "/result/dignities/0",
                    },
                ]
            },
        )

    assert response.status_code == 200, response.text
    interpretations = response.json()["interpretations"]
    assert len(interpretations) == 8
    assert {item["item_kind"] for item in interpretations} == {
        "point_intrinsic",
        "point_in_sign",
        "point_in_house",
        "motion",
        "natal_aspect",
        "house_cusp_ruler",
        "structure_indicator",
        "classical_condition",
    }
    assert all(item["status"] == "published" for item in interpretations)
