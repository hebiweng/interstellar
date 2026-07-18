from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "python"))

from interstellar_core.astronomy.validation import (  # noqa: E402
    GateStatus,
    SpiceKernelAvailability,
    evaluate_stable_gate,
    load_reference_fixture,
)

FIXTURES = Path(__file__).parent / "fixtures"


def test_public_j2000_sofa_constants_are_loaded_with_provenance() -> None:
    fixture = load_reference_fixture(FIXTURES / "j2000-sofa-constants.json")
    assert fixture.epoch.label == "J2000.0"
    assert fixture.epoch.julian_date == 2451545.0
    assert fixture.constants["DJY"]["value"] == 365.25
    assert fixture.constants["DAU"]["value"] == 149597870.7
    assert fixture.source.organization.startswith("International Astronomical Union")

    gate = evaluate_stable_gate(fixture, system_under_test_family="swiss_ephemeris")
    assert gate.status is GateStatus.BLOCKED
    assert "INDEPENDENT_POSITION_FIXTURE_MISSING" in gate.reasons


def test_missing_jpl_positions_and_kernels_block_stable_without_fabricated_data(
    tmp_path: Path,
) -> None:
    fixture = load_reference_fixture(
        FIXTURES / "jpl-de442-position-reference.unavailable.json"
    )
    (tmp_path / "naif0012.tls").write_text("fixture presence only", encoding="utf-8")
    availability = SpiceKernelAvailability.inspect(tmp_path, fixture.required_kernels)
    gate = evaluate_stable_gate(
        fixture,
        system_under_test_family="swiss_ephemeris",
        kernel_availability=availability,
    )

    assert fixture.positions == ()
    assert gate.status is GateStatus.BLOCKED
    assert "REFERENCE_FIXTURE_UNAVAILABLE" in gate.reasons
    assert "INDEPENDENT_POSITION_FIXTURE_MISSING" in gate.reasons
    assert any(reason.startswith("SPICE_KERNELS_MISSING:") for reason in gate.reasons)
