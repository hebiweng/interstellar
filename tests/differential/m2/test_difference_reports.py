from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "python"))

from interstellar_core.astronomy.validation import (  # noqa: E402
    ActualPositionSet,
    CoordinateSpec,
    EpochSpec,
    GateStatus,
    PositionValue,
    UnitSpec,
    compare_positions,
    load_reference_fixture,
)
from interstellar_core.domain import DomainError  # noqa: E402


def _synthetic_fixture(tmp_path: Path) -> Path:
    path = tmp_path / "synthetic-position-mechanics-only.json"
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "fixture_id": "TEST-SYNTHETIC-001",
                "fixture_kind": "positions",
                "review_status": "draft",
                "availability": "available",
                "source": {
                    "source_id": "synthetic-difference-mechanics",
                    "title": "Synthetic values for report mechanics only",
                    "organization": "Interstellar tests",
                    "source_uri": "urn:interstellar:test:synthetic-difference-mechanics",
                    "source_version": "1",
                    "license_identifier": "test-only",
                    "implementation_family": "synthetic_test",
                    "independently_captured": False,
                    "stable_eligible": False,
                },
                "epoch": {"label": "J2000.0", "julian_date": 2451545.0, "time_scale": "TT"},
                "coordinates": {
                    "frame": "ICRF",
                    "center": "earth",
                    "axes": "ecliptic",
                    "equinox": "J2000.0",
                },
                "units": {"angle": "degree", "distance": "astronomical_unit"},
                "tolerance": {
                    "longitude_arcsec": 1.0,
                    "latitude_arcsec": 1.0,
                    "distance_absolute": 0.00001,
                    "body_overrides": {
                        "moon": {
                            "longitude_arcsec": 3.0,
                            "latitude_arcsec": 3.0,
                            "distance_absolute": 0.00001,
                        }
                    },
                },
                "positions": [
                    {"body_id": "sun", "longitude": 359.9999, "latitude": 0.0, "distance": 1.0},
                    {"body_id": "moon", "longitude": 10.0, "latitude": 5.0, "distance": 0.00257},
                ],
                "constants": {},
                "required_kernels": [],
                "notes": ["Synthetic fixture must never satisfy Stable."],
            }
        ),
        encoding="utf-8",
    )
    return path


def _actual(*positions: PositionValue) -> ActualPositionSet:
    return ActualPositionSet(
        implementation_family="swiss_ephemeris",
        engine_version="test",
        epoch=EpochSpec("J2000.0", 2451545.0, "TT"),
        coordinates=CoordinateSpec("ICRF", "earth", "ecliptic", "J2000.0"),
        units=UnitSpec("degree", "astronomical_unit"),
        positions=positions,
    )


def test_report_contains_per_body_differences_maxima_and_source(tmp_path: Path) -> None:
    fixture = load_reference_fixture(_synthetic_fixture(tmp_path))
    report = compare_positions(
        _actual(
            PositionValue("sun", 0.0001, 0.0001, 1.000001),
            PositionValue("moon", 10.0005, 5.0005, 0.002571),
        ),
        fixture,
    )

    assert [item.body_id for item in report.bodies] == ["sun", "moon"]
    assert report.bodies[0].longitude_arcsec == pytest.approx(0.72)
    assert report.bodies[0].latitude_arcsec == pytest.approx(0.36)
    assert report.bodies[1].longitude_arcsec == pytest.approx(1.8)
    assert report.maximum_longitude_arcsec == pytest.approx(1.8)
    assert report.maximum_latitude_arcsec == pytest.approx(1.8)
    assert report.maximum_distance_absolute == pytest.approx(0.000001)
    assert all(item.passed for item in report.bodies)
    assert report.source.source_id == "synthetic-difference-mechanics"
    assert report.maturity_gate.status is GateStatus.BLOCKED
    assert report.passed is False


def test_missing_actual_body_is_a_failed_report_row(tmp_path: Path) -> None:
    fixture = load_reference_fixture(_synthetic_fixture(tmp_path))
    report = compare_positions(_actual(PositionValue("sun", 359.9999, 0.0, 1.0)), fixture)
    moon = next(item for item in report.bodies if item.body_id == "moon")
    assert moon.status == "missing_actual"
    assert moon.longitude_arcsec is None
    assert report.passed is False


def test_metadata_mismatch_is_not_silently_normalized(tmp_path: Path) -> None:
    fixture = load_reference_fixture(_synthetic_fixture(tmp_path))
    actual = ActualPositionSet(
        implementation_family="swiss_ephemeris",
        engine_version="test",
        epoch=EpochSpec("J2000.0", 2451545.0, "UTC"),
        coordinates=fixture.coordinates,
        units=fixture.units,
        positions=fixture.positions,
    )
    with pytest.raises(DomainError) as caught:
        compare_positions(actual, fixture)
    assert caught.value.code == "REFERENCE_METADATA_MISMATCH"


def test_same_family_reference_cannot_pass_independence_gate(tmp_path: Path) -> None:
    document = json.loads(_synthetic_fixture(tmp_path).read_text())
    document["source"]["implementation_family"] = "swiss_ephemeris"
    document["source"]["independently_captured"] = True
    document["source"]["stable_eligible"] = True
    document["review_status"] = "approved"
    path = tmp_path / "same-family.json"
    path.write_text(json.dumps(document), encoding="utf-8")
    fixture = load_reference_fixture(path)

    report = compare_positions(_actual(*fixture.positions), fixture)
    assert report.maturity_gate.status is GateStatus.BLOCKED
    assert "REFERENCE_NOT_INDEPENDENT" in report.maturity_gate.reasons
    assert report.passed is False
