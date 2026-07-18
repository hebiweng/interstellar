"""Deterministic offline place disambiguation and timezone candidate lookup."""

from __future__ import annotations

import math
import re
import unicodedata
from collections.abc import Iterable, Mapping, Sequence
from typing import Any

from interstellar_core.domain.errors import DomainError

from .importers import validate_coordinates, validate_timezone_feature_collection
from .models import (
    LocationCandidate,
    PlaceRecord,
    ResolutionStatus,
    TimezoneCandidate,
    TimezoneResolution,
)


def _normalize(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def _warning(code: str, message: str, **details: Any) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
        "severity": "warning",
        "path": "/timezone_id",
        "details": details,
    }


class PlaceIndex:
    """Small in-memory reference implementation of local place search."""

    def __init__(self, places: Iterable[PlaceRecord], *, dataset_version: str) -> None:
        self._places = tuple(places)
        self.dataset_version = dataset_version

    def search(
        self,
        query: str,
        *,
        country_code: str | None = None,
        admin_hints: Sequence[str] = (),
        limit: int = 10,
    ) -> tuple[tuple[PlaceRecord, float, tuple[str, ...]], ...]:
        normalized_query = _normalize(query)
        if not normalized_query:
            raise DomainError("LOCATION_QUERY_EMPTY", "location query cannot be empty")
        if country_code is not None and not re.fullmatch(r"[A-Za-z]{2}", country_code):
            raise DomainError("LOCATION_COUNTRY_INVALID", "country code must contain two letters")
        if limit < 1 or limit > 100:
            raise DomainError("LOCATION_LIMIT_INVALID", "location search limit must be 1..100")
        normalized_hints = tuple(_normalize(hint) for hint in admin_hints if _normalize(hint))
        country = country_code.upper() if country_code else None

        matches: list[tuple[PlaceRecord, float, tuple[str, ...]]] = []
        for place in self._places:
            if country and place.country_code != country:
                continue
            names = {
                "primary": _normalize(place.name),
                "ascii": _normalize(place.ascii_name),
                **{
                    f"alternate:{index}": _normalize(name)
                    for index, name in enumerate(place.alternate_names)
                },
            }
            score = 0.0
            reasons: list[str] = []
            for kind, name in names.items():
                if name == normalized_query:
                    candidate_score = 100.0 if kind == "primary" else 96.0
                    if candidate_score > score:
                        score = candidate_score
                        reasons = [f"exact_{kind.split(':')[0]}"]
                elif name.startswith(normalized_query) and score < 80.0:
                    score = 80.0
                    reasons = ["name_prefix"]
                elif normalized_query in name and score < 60.0:
                    score = 60.0
                    reasons = ["name_contains"]
            if score == 0:
                continue
            normalized_admin = tuple(_normalize(value) for value in place.admin_path)
            matched_hints = sum(hint in normalized_admin for hint in normalized_hints)
            if normalized_hints:
                if matched_hints == len(normalized_hints):
                    score += 15.0
                    reasons.append("admin_match")
                elif matched_hints:
                    score += 5.0
                    reasons.append("admin_partial")
            score += min(math.log10(max(place.population, 1)), 8.0) / 10.0
            matches.append((place, round(score, 4), tuple(reasons)))

        matches.sort(key=lambda item: (-item[1], -item[0].population, item[0].geonames_id))
        return tuple(matches[:limit])


class GeoJsonTimezoneIndex:
    """Exact polygon lookup reference implementation for verified local GeoJSON.

    Dateline-spanning polygons are rejected instead of normalized heuristically;
    the production PostGIS adapter owns that specialized geometry handling.
    """

    def __init__(self, features: Iterable[Mapping[str, Any]], *, dataset_version: str) -> None:
        collection = {"type": "FeatureCollection", "features": list(features)}
        self._features = validate_timezone_feature_collection(collection)
        self.dataset_version = dataset_version

    def lookup(self, latitude: float, longitude: float) -> tuple[str, ...]:
        validate_coordinates(latitude, longitude)
        matches: list[str] = []
        for feature in self._features:
            geometry = feature["geometry"]
            polygons = (
                geometry["coordinates"]
                if geometry["type"] == "MultiPolygon"
                else [geometry["coordinates"]]
            )
            if any(_point_in_polygon(longitude, latitude, polygon) for polygon in polygons):
                matches.append(feature["properties"]["tzid"])
        return tuple(sorted(dict.fromkeys(matches)))


def _point_in_polygon(longitude: float, latitude: float, rings: list[Any]) -> bool:
    if not rings:
        return False
    if _ring_spans_dateline(rings[0]):
        raise DomainError(
            "TIMEZONE_GEOMETRY_DATELINE_UNSUPPORTED",
            "reference resolver cannot safely normalize a dateline-spanning polygon",
        )
    if not _point_in_ring_or_boundary(longitude, latitude, rings[0]):
        return False
    return not any(_point_in_ring_strict(longitude, latitude, ring) for ring in rings[1:])


def _ring_spans_dateline(ring: list[list[float]]) -> bool:
    longitudes = [float(point[0]) for point in ring]
    return max(longitudes) - min(longitudes) > 180


def _on_segment(x: float, y: float, start: list[float], end: list[float]) -> bool:
    x1, y1 = float(start[0]), float(start[1])
    x2, y2 = float(end[0]), float(end[1])
    cross = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)
    if abs(cross) > 1e-10:
        return False
    return min(x1, x2) - 1e-10 <= x <= max(x1, x2) + 1e-10 and min(
        y1, y2
    ) - 1e-10 <= y <= max(y1, y2) + 1e-10


def _point_in_ring_or_boundary(x: float, y: float, ring: list[list[float]]) -> bool:
    if any(_on_segment(x, y, ring[index - 1], ring[index]) for index in range(len(ring))):
        return True
    return _point_in_ring_strict(x, y, ring)


def _point_in_ring_strict(x: float, y: float, ring: list[list[float]]) -> bool:
    inside = False
    previous = ring[-1]
    for current in ring:
        x1, y1 = float(previous[0]), float(previous[1])
        x2, y2 = float(current[0]), float(current[1])
        if (y1 > y) != (y2 > y):
            intersection = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < intersection:
                inside = not inside
        previous = current
    return inside


class LocationResolver:
    def __init__(self, places: PlaceIndex, timezones: GeoJsonTimezoneIndex) -> None:
        self._places = places
        self._timezones = timezones

    def resolve_timezone(self, place: PlaceRecord) -> TimezoneResolution:
        matched = self._timezones.lookup(place.latitude, place.longitude)
        if len(matched) == 1:
            return TimezoneResolution(
                status=ResolutionStatus.RESOLVED,
                candidates=(
                    TimezoneCandidate(
                        timezone_id=matched[0],
                        source="timezone_boundary_builder",
                        source_version=self._timezones.dataset_version,
                        confidence="exact_polygon",
                        boundary_match=True,
                    ),
                ),
            )
        if len(matched) > 1:
            return TimezoneResolution(
                status=ResolutionStatus.AMBIGUOUS,
                candidates=tuple(
                    TimezoneCandidate(
                        timezone_id=timezone_id,
                        source="timezone_boundary_builder",
                        source_version=self._timezones.dataset_version,
                        confidence="boundary_overlap",
                        boundary_match=True,
                    )
                    for timezone_id in matched
                ),
                warnings=(
                    _warning(
                        "TIMEZONE_BOUNDARY_AMBIGUOUS",
                        "Coordinate lies on overlapping timezone boundaries; "
                        "user selection is required",
                        candidate_count=len(matched),
                    ),
                ),
            )
        if place.timezone_id:
            return TimezoneResolution(
                status=ResolutionStatus.DEGRADED,
                candidates=(
                    TimezoneCandidate(
                        timezone_id=place.timezone_id,
                        source="geonames",
                        source_version=self._places.dataset_version,
                        confidence="dataset_hint_only",
                        boundary_match=False,
                    ),
                ),
                warnings=(
                    _warning(
                        "TIMEZONE_BOUNDARY_FALLBACK_GEONAMES",
                        "No timezone polygon matched; GeoNames hint is returned "
                        "but not auto-selected",
                    ),
                ),
            )
        return TimezoneResolution(
            status=ResolutionStatus.UNRESOLVED,
            candidates=(),
            warnings=(
                _warning(
                    "TIMEZONE_UNRESOLVED",
                    "No timezone boundary or dataset hint matched; "
                    "explicit IANA timezone is required",
                ),
            ),
        )

    def search(
        self,
        query: str,
        *,
        country_code: str | None = None,
        admin_hints: Sequence[str] = (),
        limit: int = 10,
    ) -> tuple[LocationCandidate, ...]:
        matches = self._places.search(
            query,
            country_code=country_code,
            admin_hints=admin_hints,
            limit=limit,
        )
        return tuple(
            LocationCandidate(
                place=place,
                match_score=score,
                match_reasons=reasons,
                timezone=self.resolve_timezone(place),
                source_version=self._places.dataset_version,
            )
            for place, score, reasons in matches
        )
