from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient
import pytest

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app
from interstellar_api.workflow_store import WorkflowRecordConflict, WorkflowStore


def _client() -> TestClient:
    return TestClient(create_app(ApiSettings(environment="test")))


def _professional_client() -> TestClient:
    ephemeris_path = (
        Path(__file__).resolve().parents[2] / "vendor" / "swisseph" / "ephe"
    )
    return TestClient(
        create_app(
            ApiSettings(
                environment="test",
                swiss_ephemeris_path=str(ephemeris_path),
            )
        )
    )


def _birth_payload(
    *, precision: str = "minute", local_value: str = "2000-01-01T20:00"
) -> dict:
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


def test_selected_utc_to_reproducible_m3_natal_fact_snapshot() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        response = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        )

        assert response.status_code == 201, response.text
        snapshot = response.json()
        assert snapshot["status"] == "succeeded"
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
        assert all(1 <= point["house"] <= 12 for point in points)
        assert all(point["distance_to_next_cusp_deg"] >= 0 for point in points)
        assert all(point["position"]["epoch"].startswith("JDUT:") for point in points)
        context = snapshot["result"]["astronomical_context"]
        assert context["julian_day_ut"] == 2451545.0
        assert context["julian_day_tt"] > context["julian_day_ut"]
        assert context["delta_t_seconds"] > 0
        assert 0 <= context["lunar_phase"]["illumination_fraction"] <= 1

        manifests = {
            item["calculation_id"]: item
            for item in snapshot["result"]["output_manifest"]
        }
        assert manifests["astronomy.ephemeris_core"]["status"] == "generated"
        assert manifests["astronomy.houses_angles"]["status"] == "generated"
        assert manifests["astronomy.aspects"]["status"] == "generated"
        assert manifests["natal.patterns_distributions"]["status"] == "generated"
        assert manifests["natal.standard_chart"]["status"] == "generated"
        assert len(snapshot["result"]["houses"]) == 12
        assert snapshot["result"]["aspects"]
        assert len(snapshot["result"]["distributions"]) == 3
        assert {warning["code"] for warning in snapshot["warnings"]} <= {
            "EPHEMERIS_FALLBACK_MOSHIER",
            "SWISS_EPHEMERIS_MESSAGE",
        }

        chart = snapshot["result"]["charts"][0]
        assert chart["house_set"]["system"] == "placidus"
        assert set(chart["house_set"]["angles"]) == {"asc", "dsc", "mc", "ic"}
        assigned_ids = {
            point_id
            for house in chart["house_set"]["houses"]
            for point_id in house["point_ids"]
        }
        assert assigned_ids == {point["point_id"] for point in points}
        assert all(
            0 <= aspect["actual_angle_deg"] <= 180 for aspect in chart["aspects"]
        )
        assert all(0 <= aspect["strength"] <= 1 for aspect in chart["aspects"])
        for distribution in chart["distributions"]:
            assert distribution["availability"] == "available"
            assert sum(
                category["percentage"] for category in distribution["categories"]
            ) == pytest.approx(100.0)

        fetched = client.get(f"/api/v1/calculations/{snapshot['id']}")
        assert fetched.status_code == 200
        assert fetched.json() == snapshot

        table_json = client.get(
            f"/api/v1/calculations/{snapshot['id']}/tables/table.planet_positions"
        )
        assert table_json.status_code == 200
        assert len(table_json.json()["rows"]) == 10
        assert table_json.json()["metadata"]["snapshot_id"] == snapshot["id"]
        table_csv = client.get(
            f"/api/v1/calculations/{snapshot['id']}/tables/table.planet_positions",
            params={"format": "csv"},
        )
        assert table_csv.status_code == 200
        assert table_csv.headers["content-type"].startswith("text/csv")
        assert snapshot["id"] in table_csv.text.splitlines()[1]

        expected_table_sizes = {
            "table.planet_positions": 10,
            "table.planet_speeds": 10,
            "table.house_cusps": 12,
            "table.natal_aspects": len(snapshot["result"]["aspects"]),
            "table.elements": 4,
            "table.modalities": 3,
            "table.polarity": 2,
        }
        for table_id, expected_size in expected_table_sizes.items():
            table_response = client.get(
                f"/api/v1/calculations/{snapshot['id']}/tables/{table_id}"
            )
            assert table_response.status_code == 200, table_response.text
            assert len(table_response.json()["rows"]) == expected_size
            csv_response = client.get(
                f"/api/v1/calculations/{snapshot['id']}/tables/{table_id}",
                params={"format": "csv"},
            )
            assert csv_response.status_code == 200
            assert csv_response.text.count("\n") >= expected_size

        repeated = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        ).json()
        assert repeated["input_fingerprint"] == snapshot["input_fingerprint"]
        assert repeated["result"]["points"] == snapshot["result"]["points"]
        assert (
            repeated["result"]["astronomical_context"]["julian_day_ut"]
            == (snapshot["result"]["astronomical_context"]["julian_day_ut"])
        )
        assert repeated["result"]["houses"] == snapshot["result"]["houses"]
        assert repeated["result"]["aspects"] == snapshot["result"]["aspects"]
        assert (
            repeated["result"]["distributions"] == snapshot["result"]["distributions"]
        )


def test_professional_natal_profile_materializes_signs_points_structure_and_classical() -> (
    None
):
    with _professional_client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["calculation_profile_id"] = "professional.natal.v1"
        payload["settings"]["aspect_set_id"] = "official.aspects.professional_natal.v1"
        payload["settings"]["orb_profile_id"] = "official.orbs.professional_natal.v1"
        response = client.post("/api/v1/calculations", json=payload)
        assert response.status_code == 201, response.text
        snapshot_id = response.json()["id"]
        markdown_export = client.get(
            f"/api/v1/calculations/{snapshot_id}/exports/natal-technical",
            params={"format": "markdown"},
        )
        plaintext_export = client.get(
            f"/api/v1/calculations/{snapshot_id}/exports/natal-technical",
            params={"format": "plaintext"},
        )
        ai_catalog = client.get("/api/v1/ai/providers")
        ai_without_consent = client.post(
            "/api/v1/ai/analyses",
            json={
                "snapshot_id": snapshot_id,
                "provider_id": "openai",
                "model_id": "gpt",
                "document_format": "markdown",
                "consent_to_send_snapshot": False,
            },
        )
        ai_unconfigured = client.post(
            "/api/v1/ai/analyses",
            json={
                "snapshot_id": snapshot_id,
                "provider_id": "moonshot",
                "model_id": "kimi",
                "document_format": "markdown",
                "consent_to_send_snapshot": True,
            },
        )

    snapshot = response.json()
    point_ids = [point["point_id"] for point in snapshot["result"]["points"]]
    assert len(point_ids) == 47
    assert point_ids[:10] == [
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
    assert {
        "asc",
        "dsc",
        "mc",
        "ic",
        "true_north_node",
        "true_south_node",
        "chiron",
        "ceres",
        "fortune",
        "spirit",
        "lot_basis",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
        "lot_exaltation",
        "cupido",
        "hades",
        "zeus",
        "kronos",
        "apollon",
        "admetos",
        "vulkanus",
        "poseidon",
    } <= set(point_ids)
    assert all(point["sign"] for point in snapshot["result"]["points"])
    assert all(
        0 <= point["degree_in_sign"] < 30 for point in snapshot["result"]["points"]
    )
    assert snapshot["result"]["structure"]["availability"] == "available"
    assert snapshot["result"]["classical"]["availability"] == "available"
    assert len(snapshot["result"]["dignities"]) == 7
    assert {lot["lot_id"] for lot in snapshot["result"]["lots"]} == {
        "fortune",
        "spirit",
        "lot_basis",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
        "lot_exaltation",
    }
    chart = snapshot["result"]["charts"][0]
    assert chart["aspect_evaluation"]["selected_point_count"] == 47
    assert chart["aspect_evaluation"]["evaluated_pair_count"] == 1081
    assert {aspect["type"] for aspect in chart["aspects"]} - {
        "conjunction",
        "sextile",
        "square",
        "trine",
        "opposition",
    }
    assert chart["classical"]["sect"]["sect"] in {"day", "night"}
    assert markdown_export.status_code == 200
    assert markdown_export.headers["content-type"].startswith("text/markdown")
    assert "## 完整点位" in markdown_export.text
    assert "## 完整相位" in markdown_export.text
    assert "福点 (fortune)" in markdown_export.text
    assert snapshot["input_fingerprint"] in markdown_export.text
    assert plaintext_export.status_code == 200
    assert plaintext_export.headers["content-type"].startswith("text/plain")
    assert "=== 古典与希腊化事实 ===" in plaintext_export.text
    assert ai_catalog.status_code == 200
    assert [item["provider_id"] for item in ai_catalog.json()["providers"]] == [
        "openai",
        "moonshot",
    ]
    assert ai_without_consent.status_code == 422
    assert ai_unconfigured.status_code == 409
    assert ai_unconfigured.json()["fields"]["availability"] == "blocked"


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


def test_m2_rejects_unimplemented_coordinate_mode_instead_of_degrading_silently() -> (
    None
):
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


def test_m3_point_projection_is_explicit_and_distribution_degrades() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["included_points"] = ["sun", "moon", "saturn"]
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 201, response.text
    snapshot = response.json()
    assert snapshot["status"] == "partial"
    assert [point["point_id"] for point in snapshot["result"]["points"]] == [
        "sun",
        "moon",
        "saturn",
    ]
    assert all(
        distribution["availability"] == "unavailable"
        for distribution in snapshot["result"]["distributions"]
    )
    assert "DISTRIBUTION_INPUT_INCOMPLETE" in {
        warning["code"] for warning in snapshot["warnings"]
    }


def test_m3_rejects_unknown_house_or_rule_profile_instead_of_ignoring_it() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["house_system"] = "invented_house_system"
        house_response = client.post("/api/v1/calculations", json=payload)

        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["orb_profile_id"] = "invented.orb.profile"
        orb_response = client.post("/api/v1/calculations", json=payload)

    assert house_response.status_code == 422
    assert (
        "unsupported house system"
        in house_response.json()["fields"]["subject.time_spec"]
    )
    assert orb_response.status_code == 422
    assert (
        "official.orbs.standard.v1"
        in orb_response.json()["fields"]["subject.time_spec"]
    )


def test_m3_high_latitude_fallback_is_never_silent() -> None:
    birth = _birth_payload(local_value="2000-01-01T12:00")
    birth["version"]["time_spec"]["timezone_id"] = "Europe/Oslo"
    birth["version"]["location"].update(
        {
            "name": "Svalbard",
            "latitude": 80.0,
            "longitude": 18.9553,
            "timezone_id": "Europe/Oslo",
        }
    )
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=birth).json()
        base = _calculation_payload(saved["version"]["id"])
        unavailable = client.post("/api/v1/calculations", json=base)

        fallback = _calculation_payload(saved["version"]["id"])
        fallback["settings"]["custom_parameters"] = {
            "allow_house_fallback_whole_sign": True
        }
        degraded = client.post("/api/v1/calculations", json=fallback)

    assert unavailable.status_code == 201
    assert unavailable.json()["status"] == "partial"
    assert unavailable.json()["result"]["charts"][0]["house_set"] is None
    assert "HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE" in {
        warning["code"] for warning in unavailable.json()["warnings"]
    }

    assert degraded.status_code == 201
    degraded_snapshot = degraded.json()
    assert degraded_snapshot["status"] == "partial"
    assert degraded_snapshot["result"]["charts"][0]["house_set"]["system"] == (
        "whole_sign"
    )
    house_manifest = next(
        item
        for item in degraded_snapshot["result"]["output_manifest"]
        if item["calculation_id"] == "astronomy.houses_angles"
    )
    assert house_manifest["status"] == "degraded"
