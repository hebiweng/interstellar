"""Strict JSON loader for public-reference fixtures."""

from __future__ import annotations

import json
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from interstellar_core.domain.errors import DomainError

from .models import (
    CoordinateSpec,
    EpochSpec,
    PositionValue,
    ReferenceFixture,
    ReferenceSource,
    ToleranceProfile,
    UnitSpec,
)


def _mapping(value: object, path: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise DomainError("REFERENCE_FIXTURE_INVALID", f"{path} must be an object")
    return value


def _text(value: object, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise DomainError("REFERENCE_FIXTURE_INVALID", f"{path} must be non-empty text")
    return value.strip()


def _number(value: object, path: str) -> float:
    if not isinstance(value, int | float) or isinstance(value, bool):
        raise DomainError("REFERENCE_FIXTURE_INVALID", f"{path} must be numeric")
    return float(value)


def load_reference_fixture(path: str | Path) -> ReferenceFixture:
    document = _mapping(json.loads(Path(path).read_text(encoding="utf-8")), "fixture")
    if document.get("schema_version") != 1:
        raise DomainError("REFERENCE_FIXTURE_INVALID", "schema_version must be 1")

    source_raw = _mapping(document.get("source"), "source")
    epoch_raw = _mapping(document.get("epoch"), "epoch")
    coordinates_raw = _mapping(document.get("coordinates"), "coordinates")
    units_raw = _mapping(document.get("units"), "units")
    tolerance_raw = _mapping(document.get("tolerance"), "tolerance")

    angle_unit = _text(units_raw.get("angle"), "units.angle")
    if angle_unit != "degree":
        raise DomainError(
            "REFERENCE_UNIT_UNSUPPORTED", "position fixtures must express angles in degrees"
        )

    positions_raw = document.get("positions", [])
    if not isinstance(positions_raw, list):
        raise DomainError("REFERENCE_FIXTURE_INVALID", "positions must be an array")
    positions: list[PositionValue] = []
    seen_bodies: set[str] = set()
    for index, raw_value in enumerate(positions_raw):
        raw = _mapping(raw_value, f"positions[{index}]")
        body_id = _text(raw.get("body_id"), f"positions[{index}].body_id")
        if body_id in seen_bodies:
            raise DomainError("REFERENCE_FIXTURE_INVALID", f"duplicate body: {body_id}")
        seen_bodies.add(body_id)
        longitude = _number(raw.get("longitude"), f"positions[{index}].longitude")
        latitude = _number(raw.get("latitude"), f"positions[{index}].latitude")
        distance = _number(raw.get("distance"), f"positions[{index}].distance")
        if not 0 <= longitude < 360 or not -90 <= latitude <= 90 or distance < 0:
            raise DomainError(
                "REFERENCE_POSITION_INVALID", f"position values out of range for {body_id}"
            )
        positions.append(PositionValue(body_id, longitude, latitude, distance))

    constants_raw = document.get("constants", {})
    constants = dict(_mapping(constants_raw, "constants"))
    for name, raw_value in constants.items():
        constant = _mapping(raw_value, f"constants.{name}")
        _number(constant.get("value"), f"constants.{name}.value")
        _text(constant.get("unit"), f"constants.{name}.unit")
        _number(constant.get("tolerance_absolute"), f"constants.{name}.tolerance_absolute")

    body_overrides_raw = _mapping(tolerance_raw.get("body_overrides", {}), "body_overrides")
    body_overrides = {
        str(body): {str(key): float(value) for key, value in _mapping(raw, str(body)).items()}
        for body, raw in body_overrides_raw.items()
    }
    fixture_kind = _text(document.get("fixture_kind"), "fixture_kind")
    availability = _text(document.get("availability"), "availability")
    if fixture_kind == "positions" and availability == "available" and not positions:
        raise DomainError(
            "REFERENCE_FIXTURE_INVALID", "available position fixture must contain positions"
        )

    return ReferenceFixture(
        fixture_id=_text(document.get("fixture_id"), "fixture_id"),
        fixture_kind=fixture_kind,
        review_status=_text(document.get("review_status"), "review_status"),
        source=ReferenceSource(
            source_id=_text(source_raw.get("source_id"), "source.source_id"),
            title=_text(source_raw.get("title"), "source.title"),
            organization=_text(source_raw.get("organization"), "source.organization"),
            source_uri=_text(source_raw.get("source_uri"), "source.source_uri"),
            source_version=_text(source_raw.get("source_version"), "source.source_version"),
            license_identifier=_text(
                source_raw.get("license_identifier"), "source.license_identifier"
            ),
            implementation_family=_text(
                source_raw.get("implementation_family"), "source.implementation_family"
            ),
            independently_captured=source_raw.get("independently_captured") is True,
            stable_eligible=source_raw.get("stable_eligible") is True,
        ),
        epoch=EpochSpec(
            label=_text(epoch_raw.get("label"), "epoch.label"),
            julian_date=_number(epoch_raw.get("julian_date"), "epoch.julian_date"),
            time_scale=_text(epoch_raw.get("time_scale"), "epoch.time_scale"),
        ),
        coordinates=CoordinateSpec(
            frame=_text(coordinates_raw.get("frame"), "coordinates.frame"),
            center=_text(coordinates_raw.get("center"), "coordinates.center"),
            axes=_text(coordinates_raw.get("axes"), "coordinates.axes"),
            equinox=(
                _text(coordinates_raw.get("equinox"), "coordinates.equinox")
                if coordinates_raw.get("equinox") is not None
                else None
            ),
        ),
        units=UnitSpec(
            angle=angle_unit,
            distance=_text(units_raw.get("distance"), "units.distance"),
        ),
        tolerance=ToleranceProfile(
            longitude_arcsec=_number(
                tolerance_raw.get("longitude_arcsec"), "tolerance.longitude_arcsec"
            ),
            latitude_arcsec=_number(
                tolerance_raw.get("latitude_arcsec"), "tolerance.latitude_arcsec"
            ),
            distance_absolute=_number(
                tolerance_raw.get("distance_absolute"), "tolerance.distance_absolute"
            ),
            body_overrides=body_overrides,
        ),
        positions=tuple(positions),
        constants=constants,
        required_kernels=tuple(
            _text(value, "required_kernels[]") for value in document.get("required_kernels", [])
        ),
        availability=availability,
        notes=tuple(_text(value, "notes[]") for value in document.get("notes", [])),
    )
