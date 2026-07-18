"""Position differencing and explicit Stable maturity gates."""

from __future__ import annotations

from dataclasses import replace

from interstellar_core.domain.errors import DomainError

from .models import (
    ActualPositionSet,
    BodyDifference,
    DifferenceReport,
    GateStatus,
    MaturityGate,
    ReferenceFixture,
    SpiceKernelAvailability,
)


def _angular_difference_degrees(actual: float, expected: float) -> float:
    return abs((actual - expected + 180.0) % 360.0 - 180.0)


def evaluate_stable_gate(
    fixture: ReferenceFixture,
    *,
    system_under_test_family: str,
    kernel_availability: SpiceKernelAvailability | None = None,
) -> MaturityGate:
    reasons: list[str] = []
    status = GateStatus.PASSED

    if fixture.availability != "available":
        status = GateStatus.UNAVAILABLE
        reasons.append("REFERENCE_FIXTURE_UNAVAILABLE")
    if fixture.fixture_kind != "positions" or not fixture.positions:
        status = GateStatus.BLOCKED
        reasons.append("INDEPENDENT_POSITION_FIXTURE_MISSING")
    if fixture.source.implementation_family == system_under_test_family:
        status = GateStatus.BLOCKED
        reasons.append("REFERENCE_NOT_INDEPENDENT")
    if not fixture.source.independently_captured or not fixture.source.stable_eligible:
        status = GateStatus.BLOCKED
        reasons.append("REFERENCE_NOT_STABLE_ELIGIBLE")
    if fixture.review_status not in {"independently_captured", "approved"}:
        status = GateStatus.BLOCKED
        reasons.append("REFERENCE_REVIEW_INCOMPLETE")
    if fixture.required_kernels:
        if kernel_availability is None:
            status = GateStatus.BLOCKED
            reasons.append("SPICE_KERNEL_INVENTORY_UNAVAILABLE")
        elif kernel_availability.missing:
            status = GateStatus.BLOCKED
            reasons.append("SPICE_KERNELS_MISSING:" + ",".join(kernel_availability.missing))

    return MaturityGate(
        target="stable",
        status=status,
        reasons=tuple(dict.fromkeys(reasons)),
        source_ids=(fixture.source.source_id,),
    )


def _assert_metadata_match(actual: ActualPositionSet, fixture: ReferenceFixture) -> None:
    comparisons = {
        "epoch.julian_date": (actual.epoch.julian_date, fixture.epoch.julian_date),
        "epoch.time_scale": (actual.epoch.time_scale, fixture.epoch.time_scale),
        "coordinates.frame": (actual.coordinates.frame, fixture.coordinates.frame),
        "coordinates.center": (actual.coordinates.center, fixture.coordinates.center),
        "coordinates.axes": (actual.coordinates.axes, fixture.coordinates.axes),
        "coordinates.equinox": (actual.coordinates.equinox, fixture.coordinates.equinox),
        "units.angle": (actual.units.angle, fixture.units.angle),
        "units.distance": (actual.units.distance, fixture.units.distance),
    }
    mismatches = [name for name, values in comparisons.items() if values[0] != values[1]]
    if mismatches:
        raise DomainError(
            "REFERENCE_METADATA_MISMATCH",
            "actual and reference metadata differ: " + ", ".join(mismatches),
        )


def compare_positions(
    actual: ActualPositionSet,
    fixture: ReferenceFixture,
    *,
    kernel_availability: SpiceKernelAvailability | None = None,
) -> DifferenceReport:
    if fixture.fixture_kind != "positions" or not fixture.positions:
        raise DomainError(
            "REFERENCE_POSITIONS_UNAVAILABLE",
            f"fixture {fixture.fixture_id} does not contain independent positions",
        )
    _assert_metadata_match(actual, fixture)
    gate = evaluate_stable_gate(
        fixture,
        system_under_test_family=actual.implementation_family,
        kernel_availability=kernel_availability,
    )
    actual_by_body = {position.body_id: position for position in actual.positions}
    results: list[BodyDifference] = []
    for reference in fixture.positions:
        longitude_tolerance = fixture.tolerance.for_body(
            reference.body_id, "longitude_arcsec"
        )
        latitude_tolerance = fixture.tolerance.for_body(reference.body_id, "latitude_arcsec")
        distance_tolerance = fixture.tolerance.for_body(
            reference.body_id, "distance_absolute"
        )
        actual_position = actual_by_body.get(reference.body_id)
        if actual_position is None:
            results.append(
                BodyDifference(
                    body_id=reference.body_id,
                    longitude_arcsec=None,
                    latitude_arcsec=None,
                    distance_absolute=None,
                    longitude_tolerance_arcsec=longitude_tolerance,
                    latitude_tolerance_arcsec=latitude_tolerance,
                    distance_tolerance_absolute=distance_tolerance,
                    passed=False,
                    status="missing_actual",
                )
            )
            continue
        longitude_error = _angular_difference_degrees(
            actual_position.longitude, reference.longitude
        ) * 3600.0
        latitude_error = abs(actual_position.latitude - reference.latitude) * 3600.0
        distance_error = abs(actual_position.distance - reference.distance)
        passed = (
            longitude_error <= longitude_tolerance
            and latitude_error <= latitude_tolerance
            and distance_error <= distance_tolerance
        )
        results.append(
            BodyDifference(
                body_id=reference.body_id,
                longitude_arcsec=longitude_error,
                latitude_arcsec=latitude_error,
                distance_absolute=distance_error,
                longitude_tolerance_arcsec=longitude_tolerance,
                latitude_tolerance_arcsec=latitude_tolerance,
                distance_tolerance_absolute=distance_tolerance,
                passed=passed,
                status="compared",
            )
        )

    longitudes = [item.longitude_arcsec for item in results if item.longitude_arcsec is not None]
    latitudes = [item.latitude_arcsec for item in results if item.latitude_arcsec is not None]
    distances = [item.distance_absolute for item in results if item.distance_absolute is not None]
    numerical_pass = bool(results) and all(item.passed for item in results)
    if not numerical_pass and gate.status is GateStatus.PASSED:
        gate = replace(gate, status=GateStatus.FAILED, reasons=("TOLERANCE_EXCEEDED",))
    return DifferenceReport(
        fixture_id=fixture.fixture_id,
        source=fixture.source,
        engine_family=actual.implementation_family,
        engine_version=actual.engine_version,
        epoch=fixture.epoch,
        coordinates=fixture.coordinates,
        units=fixture.units,
        bodies=tuple(results),
        maximum_longitude_arcsec=max(longitudes) if longitudes else None,
        maximum_latitude_arcsec=max(latitudes) if latitudes else None,
        maximum_distance_absolute=max(distances) if distances else None,
        passed=numerical_pass and gate.status is GateStatus.PASSED,
        maturity_gate=gate,
    )
