"""Immutable values for independently sourced astronomy fixtures and reports."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any


class GateStatus(StrEnum):
    PASSED = "passed"
    FAILED = "failed"
    BLOCKED = "blocked"
    UNAVAILABLE = "unavailable"


@dataclass(frozen=True, slots=True)
class ReferenceSource:
    source_id: str
    title: str
    organization: str
    source_uri: str
    source_version: str
    license_identifier: str
    implementation_family: str
    independently_captured: bool
    stable_eligible: bool


@dataclass(frozen=True, slots=True)
class EpochSpec:
    label: str
    julian_date: float
    time_scale: str


@dataclass(frozen=True, slots=True)
class CoordinateSpec:
    frame: str
    center: str
    axes: str
    equinox: str | None


@dataclass(frozen=True, slots=True)
class UnitSpec:
    angle: str
    distance: str


@dataclass(frozen=True, slots=True)
class ToleranceProfile:
    longitude_arcsec: float
    latitude_arcsec: float
    distance_absolute: float
    body_overrides: dict[str, dict[str, float]]

    def for_body(self, body_id: str, field: str) -> float:
        return self.body_overrides.get(body_id, {}).get(field, getattr(self, field))


@dataclass(frozen=True, slots=True)
class PositionValue:
    body_id: str
    longitude: float
    latitude: float
    distance: float


@dataclass(frozen=True, slots=True)
class ReferenceFixture:
    fixture_id: str
    fixture_kind: str
    review_status: str
    source: ReferenceSource
    epoch: EpochSpec
    coordinates: CoordinateSpec
    units: UnitSpec
    tolerance: ToleranceProfile
    positions: tuple[PositionValue, ...]
    constants: dict[str, dict[str, Any]]
    required_kernels: tuple[str, ...]
    availability: str
    notes: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class ActualPositionSet:
    implementation_family: str
    engine_version: str
    epoch: EpochSpec
    coordinates: CoordinateSpec
    units: UnitSpec
    positions: tuple[PositionValue, ...]


@dataclass(frozen=True, slots=True)
class SpiceKernelAvailability:
    required: tuple[str, ...]
    available: tuple[str, ...]

    @classmethod
    def inspect(
        cls, directory: str | Path, required: tuple[str, ...]
    ) -> SpiceKernelAvailability:
        """Inspect an already provisioned local kernel directory without downloading."""

        root = Path(directory)
        available = tuple(kernel for kernel in required if (root / kernel).is_file())
        return cls(required=required, available=available)

    @property
    def missing(self) -> tuple[str, ...]:
        available = set(self.available)
        return tuple(kernel for kernel in self.required if kernel not in available)


@dataclass(frozen=True, slots=True)
class MaturityGate:
    target: str
    status: GateStatus
    reasons: tuple[str, ...]
    source_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class BodyDifference:
    body_id: str
    longitude_arcsec: float | None
    latitude_arcsec: float | None
    distance_absolute: float | None
    longitude_tolerance_arcsec: float
    latitude_tolerance_arcsec: float
    distance_tolerance_absolute: float
    passed: bool
    status: str


@dataclass(frozen=True, slots=True)
class DifferenceReport:
    fixture_id: str
    source: ReferenceSource
    engine_family: str
    engine_version: str
    epoch: EpochSpec
    coordinates: CoordinateSpec
    units: UnitSpec
    bodies: tuple[BodyDifference, ...]
    maximum_longitude_arcsec: float | None
    maximum_latitude_arcsec: float | None
    maximum_distance_absolute: float | None
    passed: bool
    maturity_gate: MaturityGate
