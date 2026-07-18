"""Location values compatible with the canonical Location schema."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any


class ResolutionStatus(StrEnum):
    RESOLVED = "resolved"
    AMBIGUOUS = "ambiguous"
    DEGRADED = "degraded"
    UNRESOLVED = "unresolved"


@dataclass(frozen=True, slots=True)
class PlaceRecord:
    geonames_id: int
    name: str
    ascii_name: str
    alternate_names: tuple[str, ...]
    latitude: float
    longitude: float
    country_code: str
    admin_path: tuple[str, ...]
    feature_class: str
    feature_code: str
    population: int
    timezone_id: str | None
    elevation_m: float | None = None


@dataclass(frozen=True, slots=True)
class TimezoneCandidate:
    timezone_id: str
    source: str
    source_version: str
    confidence: str
    boundary_match: bool


@dataclass(frozen=True, slots=True)
class TimezoneResolution:
    status: ResolutionStatus
    candidates: tuple[TimezoneCandidate, ...]
    warnings: tuple[dict[str, Any], ...] = ()

    @property
    def selected_timezone_id(self) -> str | None:
        if self.status is ResolutionStatus.RESOLVED and len(self.candidates) == 1:
            return self.candidates[0].timezone_id
        return None


@dataclass(frozen=True, slots=True)
class LocationCandidate:
    place: PlaceRecord
    match_score: float
    match_reasons: tuple[str, ...]
    timezone: TimezoneResolution
    source_version: str
    warnings: tuple[dict[str, Any], ...] = field(default_factory=tuple)

    def to_canonical(self) -> dict[str, Any]:
        warnings = [*self.warnings, *self.timezone.warnings]
        return {
            "name": self.place.name,
            "country_code": self.place.country_code,
            "admin_path": list(self.place.admin_path),
            "latitude": self.place.latitude,
            "longitude": self.place.longitude,
            "elevation_m": self.place.elevation_m,
            "timezone_id": self.timezone.selected_timezone_id,
            "geonames_id": self.place.geonames_id,
            "source": {
                "kind": "geonames",
                "description": "GeoNames local verified dataset",
                "uri": None,
                "version": self.source_version,
                "license": "CC-BY-4.0",
                "retrieved_at": None,
            },
            "source_version": self.source_version,
            "accuracy_m": None,
            "warnings": warnings,
        }
