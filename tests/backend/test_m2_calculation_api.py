from __future__ import annotations

from fastapi.testclient import TestClient
import pytest

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app
from interstellar_api.workflow_store import WorkflowRecordConflict, WorkflowStore


def _client() -> TestClient:
    return TestClient(create_app(ApiSettings(environment="test")))


def _birth_payload(*, precision: str = "minute", local_value: str = "2000-01-01T20:00") -> dict:
    return {
        "workspace_id": "workspace-m2",
        "version": {
            "kind": "person",
            "display_name": "M2 Virtual Subject",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": local_value,
                "precision": precision,
                "timezone_id": "Asia/Shanghai" if precision != "date" else None,
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high" if precision != "date" else "unknown",
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


def _calculation_payload(version_id: str) -> dict:
    return {
        "subject": {"subject_version_id": version_id},
        "chart": {"family": "natal", "technique": "natal.standard_chart"},
        "settings": {
            "zodiac": "tropical",
            "house_system": "placidus",
            "center": "geocentric",
            "coordinate_frame": "ecliptic",
            "node_type": "true",
            "aspect_set_id": "official.aspects.major.v1",
            "orb_profile_id": "official.orbs.standard.v1",
            "included_points": [],
            "custom_parameters": {},
        },
        "rule_pack_hash": f"sha256:{'a' * 64}",
        "dataset_versions": {},
        "outputs": ["snapshot", "json"],
    }


def test_selected_utc_to_reproducible_astronomical_snapshot() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        response = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        )

        assert response.status_code == 201, response.text
        snapshot = response.json()
        assert snapshot["status"] == "partial"
        assert snapshot["maturity"] == "experimental"
        assert snapshot["engine"]["version"] == "0.1.0"
        assert snapshot["adapters"][0]["name"] == "pysweph"
        assert snapshot["adapters"][0]["version"] == "2.10.3.6"
        assert snapshot["input_fingerprint"].startswith("sha256:")

        points = snapshot["result"]["points"]
        assert [point["point_id"] for point in points] == [
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
        ]
        assert all(point["house"] is None for point in points)
        assert all(point["position"]["epoch"].startswith("JDUT:") for point in points)
        context = snapshot["result"]["astronomical_context"]
        assert context["julian_day_ut"] == 2451545.0
        assert context["julian_day_tt"] > context["julian_day_ut"]
        assert context["delta_t_seconds"] > 0
        assert 0 <= context["lunar_phase"]["illumination_fraction"] <= 1

        manifests = {item["calculation_id"]: item for item in snapshot["result"]["output_manifest"]}
        assert manifests["astronomy.ephemeris_core"]["status"] == "generated"
        assert manifests["natal.standard_chart"]["status"] == "blocked"
        assert snapshot["result"]["houses"] == []
        assert snapshot["result"]["aspects"] == []
        assert snapshot["warnings"][0]["code"] == "M2_PARTIAL_CHART"

        fetched = client.get(f"/api/v1/calculations/{snapshot['id']}")
        assert fetched.status_code == 200
        assert fetched.json() == snapshot

        repeated = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        ).json()
        assert repeated["input_fingerprint"] == snapshot["input_fingerprint"]
        assert repeated["result"]["points"] == snapshot["result"]["points"]
        assert repeated["result"]["astronomical_context"]["julian_day_ut"] == (
            snapshot["result"]["astronomical_context"]["julian_day_ut"]
        )


def test_unknown_birth_time_never_runs_as_midnight() -> None:
    with _client() as client:
        saved = client.post(
            "/api/v1/subjects",
            json=_birth_payload(precision="date", local_value="2000-01-01"),
        ).json()
        response = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        )

    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    assert "cannot be guessed" in response.json()["fields"]["subject.time_spec"]


def test_m2_rejects_unimplemented_coordinate_mode_instead_of_degrading_silently() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["center"] = "heliocentric"
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 422
    assert response.json()["fields"]["settings.center"] == (
        "M2 supports geocentric positions only"
    )


def test_process_adapter_rejects_snapshot_overwrite() -> None:
    store = WorkflowStore()
    snapshot = {"id": "calculation-immutable", "value": 1}
    store.put_snapshot(snapshot)
    snapshot["value"] = 2
    assert store.get_snapshot("calculation-immutable")["value"] == 1
    with pytest.raises(WorkflowRecordConflict, match="already exists"):
        store.put_snapshot({"id": "calculation-immutable", "value": 3})
