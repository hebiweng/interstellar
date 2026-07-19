from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml
from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


ROOT = Path(__file__).resolve().parents[3]
FIXTURE_PATH = Path(__file__).parent / "fixtures" / "competitor-export-reference.yaml"


def _fixture() -> dict[str, Any]:
    return yaml.safe_load(FIXTURE_PATH.read_text(encoding="utf-8"))


def _circular_difference(left: float, right: float) -> float:
    return abs((left - right + 180.0) % 360.0 - 180.0)


def _subject_payload(case: dict[str, Any]) -> dict[str, Any]:
    spec = case["input"]
    return {
        "workspace_id": "workspace-natal-difference",
        "version": {
            "kind": "person",
            "display_name": "User supplied numeric comparison",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": spec["local_value"],
                "precision": "second",
                "timezone_id": spec["timezone_id"],
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high",
                "source": {"kind": "user_supplied_numeric_fixture"},
                "warnings": [],
            },
            "location": {
                "name": "Beijing",
                "country_code": "CN",
                "latitude": spec["latitude_deg"],
                "longitude": spec["longitude_deg"],
                "timezone_id": spec["timezone_id"],
                "source": "user_supplied_numeric_fixture",
                "warnings": [],
            },
            "attributes": {},
            "source": {"kind": "user_supplied_numeric_fixture"},
        },
    }


def _calculation_payload(version_id: str, case: dict[str, Any]) -> dict[str, Any]:
    spec = case["input"]
    return {
        "subject": {"subject_version_id": version_id},
        "chart": {"family": "natal", "technique": "natal.standard_chart"},
        "settings": {
            "calculation_profile_id": "professional.natal.v1",
            "analysis_system_id": "natal.integrated.v1",
            "zodiac": spec["zodiac"],
            "house_system": spec["house_system"],
            "center": "geocentric",
            "coordinate_frame": "ecliptic",
            "node_type": "both",
            "high_latitude_policy": "block",
            "aspect_set_id": "official.aspects.professional_natal.v1",
            "orb_profile_id": "official.orbs.professional_natal.v1",
            "point_set_ids": ["points.professional.default.v1"],
            "included_points": [],
            "included_aspect_ids": [],
            "custom_parameters": {},
        },
        "rule_pack_hash": f"sha256:{'a' * 64}",
        "dataset_versions": {"tzdb": "system-test"},
        "outputs": ["snapshot", "json"],
    }


def test_professional_natal_matches_user_supplied_displayed_numeric_reference() -> None:
    case = _fixture()
    assert case["source"]["authoritative"] is False
    assert case["source"]["stable_eligible"] is False
    ephemeris_path = ROOT / "vendor" / "swisseph" / "ephe"
    app = create_app(
        ApiSettings(environment="test", swiss_ephemeris_path=str(ephemeris_path))
    )
    with TestClient(app) as client:
        saved = client.post("/api/v1/subjects", json=_subject_payload(case))
        assert saved.status_code == 201, saved.text
        calculated = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved.json()["version"]["id"], case),
        )
        assert calculated.status_code == 201, calculated.text
        snapshot = calculated.json()
        result = snapshot["result"]

    points = {point["point_id"]: point for point in result["points"]}
    assert {
        "cupido",
        "hades",
        "zeus",
        "kronos",
        "apollon",
        "admetos",
        "vulkanus",
        "poseidon",
    } <= points.keys()
    assert "seorbel" not in json.dumps(snapshot["warnings"], ensure_ascii=False).lower()
    tolerance = float(case["tolerance"]["displayed_longitude_deg"])
    for expected in case["expected"]["points"]:
        actual = points[expected["point_id"]]
        assert actual["sign"] == expected["sign"]
        assert actual["house"] == expected["house"]
        longitude = actual["position"]["ecliptic"]["longitude_deg"]
        assert _circular_difference(longitude, expected["longitude_deg"]) <= tolerance
        if "motion_state" in expected:
            assert actual["position"]["motion_state"] == expected["motion_state"]

    houses = {house["number"]: house for house in result["houses"]}
    cusp_tolerance = float(case["tolerance"]["displayed_cusp_deg"])
    for expected in case["expected"]["houses"]:
        actual = houses[expected["number"]]
        assert actual["sign"] == expected["sign"]
        assert _circular_difference(
            actual["cusp_longitude_deg"], expected["cusp_longitude_deg"]
        ) <= cusp_tolerance

    # The comparison covers the complete product-facing core, not just one point.
    assert len(case["expected"]["points"]) == 29
    assert len(case["expected"]["houses"]) == 12
